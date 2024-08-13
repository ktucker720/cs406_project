import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'place_select.dart';

// Supports viewing and editing reviews
enum DisplayMode { view, form, map }

// Review data
class ReviewModel {
  final int id;
  DisplayMode displayMode;
  String? docId;
  Place? place;
  DateTime? date;
  int? stars;
  String? headline;
  String? description;

  ReviewModel.fromData(this.id, this.displayMode, this.docId, Map<String, dynamic> data) {
    if(data["place"] != null) {
      place = Place.fromData(data["place"]);
    }
    if (data["date"] != null) {
      date = DateTime.fromMicrosecondsSinceEpoch(data["date"].microsecondsSinceEpoch);
    }
    stars = data["stars"];
    headline = data["headline"];
    description = data["description"];
  }

  ReviewModel.fromOther(ReviewModel other) :
    id = other.id,
    displayMode = other.displayMode,
    docId = other.docId,
    place = other.place,
    date = other.date,
    stars = other.stars,
    headline = other.headline,
    description = other.description;

  ReviewModel copyWith() {
    return ReviewModel.fromOther(this);
  }

  bool isNew() {
    return (docId == null);
  }
}

final reviewsProvider = StateNotifierProvider<ReviewsNotifier, List<ReviewModel>>((ref) {
  return ReviewsNotifier();
});

// The review list state management with Riverpod
class ReviewsNotifier extends StateNotifier<List<ReviewModel>> {
  int nextId = 1;
  // Backup old data when editing
  Map<int, ReviewModel> oldData = {};

  ReviewsNotifier() : super([]);

  // Clear screen of all entries, useful when switching users
  void clear() {
    state = [];
  }

  void loadFromDatabase() {
    FirebaseFirestore.instance.collection("reviews")
    .where('uid', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
    .orderBy('date', descending: true)
    .get()
    .then((s) {
      List<ReviewModel> newReviews = [];
      for(var d in s.docs) {
        newReviews.add(ReviewModel.fromData(nextId++, DisplayMode.view, d.id, d.data()));
      }
      state = newReviews;
    })
    .catchError((error) {
      state = [];
    });
  }

  void beginReview() {
    // Start a new review at the top if not already there
    if(state.isEmpty || !state[0].isNew()) {
      state = [ReviewModel.fromData(nextId++, DisplayMode.map, null, {}), ...state];
    }
  }

  void cancelReviewEdit(int id) {
    for(int i = 0; i < state.length; i++) {
      if(state[i].id == id) {
        if(state[i].isNew()) {
          // Just remove cancelled new reviews
          deleteReview(id);
        } else {
          // Revert to old version backup
          state[i] = oldData.remove(id)!;
          // Change display from editing to viewing
          state[i].displayMode = DisplayMode.view;
          // Force state update
          state = [...state];
        }
      }
    }
  }

  void submitReviewEdit(int id, ReviewModel m) {
    for(int i = 0; i < state.length; i++) {
      if(state[i].id == id) {
        var newData = {
          "uid": FirebaseAuth.instance.currentUser!.uid,
          "place": m.place!.toData(),
          "date": m.date!,
          "stars": m.stars!,
          "headline": m.headline!,
          "description": m.description!
        };
        if(state[i].isNew()) {
          // Add the new review to the database
          FirebaseFirestore.instance.collection("reviews").add(newData).then((documentSnapshot) {
            // Switch from form panel to view panel
            m.displayMode = DisplayMode.view;
            // Get the new ID
            m.docId = documentSnapshot.id;
            // Force state update
            state[i] = m;
            state = [...state];
          });
        } else {
          // Update the existing review in the database
          FirebaseFirestore.instance.collection("reviews").doc(m.docId).set(newData).then((_) {
            // Switch from form panel to view panel
            m.displayMode = DisplayMode.view;
            // Remove old version backup
            oldData.remove(id);
            // Force state update
            state[i] = m;
            state = [...state];
          });
        }
      }
    }
  }

  void cancelPlaceSelect(int id) {
    for(int i = 0; i < state.length; i++) {
      if(state[i].id == id) {
        // Switch from map panel to form panel, no changes to place
        state[i].displayMode = DisplayMode.form;
      }
    }
    // Force state update
    state = [...state];
  }

  void submitPlaceSelect(int id, Place p) {
    for(int i = 0; i < state.length; i++) {
      if(state[i].id == id) {
        // Switch from map panel to form panel
        state[i].displayMode = DisplayMode.form;
        state[i].place = p;
      }
    }
    // Force state update
    state = [...state];
  }

  void beginReviewEdit(int id) {
    for(int i = 0; i < state.length; i++) {
      if(state[i].id == id) {
        // Backup a copy of the existing data
        oldData[id] = state[i].copyWith();
        // Switch from view panel to form panel
        state[i].displayMode = DisplayMode.form;
      }
    }
    // Force state update
    state = [...state];
  }

  void beginPlaceSelect(int id) {
    for(int i = 0; i < state.length; i++) {
      if(state[i].id == id) {
        // Switch from form panel to map panel
        state[i].displayMode = DisplayMode.map;
      }
    }
    // Force state update
    state = [...state];
  }

  void deleteReview(int id) {
    for(int i = 0; i < state.length; i++) {
      if(state[i].id == id) {
        if(!state[i].isNew()) {
          // Delete existing reviews from database
          FirebaseFirestore.instance.collection("reviews").doc(state[i].docId).delete();
        }
        state = [...state.where((element) {return element.id != id;})];
        oldData.remove(id);
      }
    }
  }
}

// A completed review entry that can be edited or deleted
class ReviewEntry extends StatelessWidget {
  final ReviewModel data;
  final void Function(int) onEdit;
  final void Function(int) onDelete;

  const ReviewEntry({super.key, required this.data, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 180,
                child: Text(
                  "${data.place!.name}, ${data.place!.city}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 20),
              SizedBox(
                width: 10,
                child: Text(
                  data.stars!.toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold)
                )
              ),
              const SizedBox(
                width: 20,
                child: Icon(Icons.star)
              ),
              const SizedBox(width: 20),
              SizedBox(
                width: 80,
                child: Text(
                  "${data.date!.month.toString()}/${data.date!.day.toString()}/${data.date!.year.toString()}"
                ),
              ),
              const SizedBox(width: 20),
              IconButton(
                iconSize: 20,
                icon: const Icon(Icons.edit),
                style: IconButton.styleFrom(backgroundColor: const Color.fromARGB(255, 230, 230, 255)),
                onPressed: () {
                  onEdit(data.id);
                },
              ),
              const SizedBox(width: 20),
              IconButton(
                iconSize: 20,
                icon: const Icon(Icons.delete),
                style: IconButton.styleFrom(backgroundColor: const Color.fromARGB(255, 230, 230, 255)),
                onPressed: () {
                  onDelete(data.id);
                },
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Flexible(child: Text(
                data.headline!.toString(),
                style: const TextStyle(fontWeight: FontWeight.bold)
              ))
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Flexible(child: Text(data.description!.toString()))
            ],
          ),
        ],
      )
    );
  }
}

// A form for editing a review
class ReviewEntryForm extends ConsumerStatefulWidget {
  final ReviewModel initialData;
  final void Function(int) onCancel;
  final void Function(int, ReviewModel) onSubmit;

  const ReviewEntryForm({super.key, required this.initialData, required this.onCancel, required this.onSubmit});

  @override
  ReviewEntryFormState createState() {
    return ReviewEntryFormState();
  }
}

class ReviewEntryFormState extends ConsumerState<ReviewEntryForm> {
  final List<int> starList = <int>[1, 2, 3, 4, 5];
  final _formKey = GlobalKey<FormState>();
  ReviewModel? newData;

  @override
  void initState() {
    super.initState();
    newData ??= widget.initialData;
  }

  @override
  Widget build(BuildContext context) {
    var placeText = "Place ";
    if(newData?.place?.name != null && newData?.place?.city != null) {
      placeText += "(${newData?.place?.name}, ${newData?.place?.city})";
    }
    else  {
      placeText += "(Tap to Select)";
    }
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ElevatedButton(
            onPressed: () {
              ref.read(reviewsProvider.notifier).beginPlaceSelect(newData!.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 230, 230, 255)),
            child: Text(placeText)
          ),
          DropdownButtonFormField<int>(
            value: newData?.stars,
            items: starList.map<DropdownMenuItem<int>>((int value) {
              return DropdownMenuItem<int>(value: value, child: Text(value.toString()));
            }).toList(),
            decoration: const InputDecoration(
              labelText: 'Rating',
            ),
            onChanged: (int? value) {
              // This is called when the user selects an item.
              setState(() {
                newData!.stars = value;
              });
            },
            validator: (value) {
              if (value == null) {
                return 'Please select a rating';
              }
              return null;
          },),
          TextFormField(
              decoration: const InputDecoration(
                labelText: 'Headline',
              ),
              initialValue: newData?.headline ?? "",
              onChanged: (newValue) {
                newData!.headline = newValue;
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a headline';
                }
                return null;}
          ),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Description',
            ),
            initialValue: newData?.description ?? "",
            onChanged: (newValue) {
              newData!.description = newValue;
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a description';
              }
              return null;}
              ),
          Row(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 10, 0),
              child: ElevatedButton(
                onPressed: () {
                  widget.onCancel.call(widget.initialData.id);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 230, 230, 255)),
                child: const Text('Cancel')
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 0, 0),
              child: ElevatedButton(
                onPressed: () {
                  if ((_formKey.currentState?.validate() ?? false) && (newData?.place != null)) {
                    newData!.date = DateTime.now();
                    // Create a new version of the review with the new form data
                    widget.onSubmit.call(newData!.id, newData!);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 230, 230, 255)),
                child: const Text('Submit')
              ),
            ),
          ],),
        ],
      ),
    );
  }
}

// An interactive map for selecting a review's place
class ReviewEntryMap extends ConsumerWidget {
  final ReviewModel initialData;
  final void Function(int) onCancel;
  final void Function(int, Place) onSubmit;

  const ReviewEntryMap({super.key, required this.initialData, required this.onCancel, required this.onSubmit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PlaceSearchMap(
      initialData: initialData.place,
      onCancel: () {onCancel(initialData.id);},
      onSubmit: (Place p) {onSubmit(initialData.id, p);}
    );
  }
}

// An interactive list of reviews and review forms
class ReviewsList extends ConsumerWidget {
  const ReviewsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(reviewsProvider);
    return ListView.separated(
      itemCount: reviews.length,
      separatorBuilder: (context, index) {
        return const Divider(height: 10);
      },
      itemBuilder: (context, index) {
        final review = reviews[index].copyWith();
        if(review.displayMode == DisplayMode.form) {
          return Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.grey,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(10))
            ),
            child: ReviewEntryForm(
              initialData: review,
              onCancel: (int id) {ref.read(reviewsProvider.notifier).cancelReviewEdit(id);},
              onSubmit: (int id, ReviewModel m) {ref.read(reviewsProvider.notifier).submitReviewEdit(id, m);}));
        }
        else if(review.displayMode == DisplayMode.map) {
          return Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.grey,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(10))
            ),
            child: ReviewEntryMap(
              initialData: review,
              onCancel: (int id) {ref.read(reviewsProvider.notifier).cancelPlaceSelect(id);},
              onSubmit: (int id, Place p) {ref.read(reviewsProvider.notifier).submitPlaceSelect(id, p);}));
        }
        else {
          return Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.grey,
                ),
                borderRadius: const BorderRadius.all(Radius.circular(10))
            ),
            child: ReviewEntry(
              data: review,
              onEdit: (int id) {ref.read(reviewsProvider.notifier).beginReviewEdit(id);},
              onDelete: (int id) {ref.read(reviewsProvider.notifier).deleteReview(id);}));
        }
      },
    );
  }
}

class ReviewsScreen extends ConsumerWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Reviews', style: Theme.of(context).textTheme.headlineLarge),
        backgroundColor: const Color.fromARGB(255, 230, 230, 255),
        actions: [
          IconButton(
            iconSize: 50,
            color: Colors.lightGreen,
            icon: const Icon(Icons.add),
            onPressed: () {
              // Instruct the state manager to create a new review
              ref.read(reviewsProvider.notifier).beginReview();
            },
          ),
          IconButton(
            iconSize: 50,
            color: Colors.lightBlue,
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<ProfileScreen>(
                  builder: (context) => ProfileScreen(
                    appBar: AppBar(
                      title: Text('My Profile', style: Theme.of(context).textTheme.displaySmall),
                      backgroundColor: const Color.fromARGB(255, 230, 230, 255),
                    ),
                    actions: [
                      SignedOutAction((context) {
                        Navigator.of(context).pop();
                      })
                    ],
                  ),
                ),
              );
            },
          ),
        ],
        automaticallyImplyLeading: false,
      ),
      body: Container(padding: const EdgeInsets.all(10), child: const ReviewsList()),
    );
  }
}
