import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Review data
class ReviewModel {
  final int id;
  bool isNew;
  bool isEditing;
  String? docId;
  String? name;
  String? city;
  DateTime? date;
  int? stars;
  String? headline;
  String? description;

  ReviewModel(this.id, this.isNew, this.isEditing, this.docId, Map<String, dynamic> data) {
    name = data["name"];
    city = data["city"];
    if (data["date"] != null) {
      date = DateTime.fromMicrosecondsSinceEpoch(data["date"].microsecondsSinceEpoch);
    }
    stars = data["stars"];
    headline = data["headline"];
    description = data["description"];
  }

  ReviewModel.fromOther(ReviewModel other) :
    id = other.id,
    isNew = other.isNew,
    isEditing = other.isEditing,
    docId = other.docId,
    name = other.name,
    city = other.city,
    date = other.date,
    stars = other.stars,
    headline = other.headline,
    description = other.description;

  ReviewModel copyWith() {
    return ReviewModel.fromOther(this);
  }
}

// A completed review entry that can be edited or deleted
class ReviewEntry extends StatelessWidget {
  const ReviewEntry({super.key, required this.data, required this.onEdit, required this.onDelete});

  final ReviewModel data;
  final void Function(int) onEdit;
  final void Function(int) onDelete;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                Text(
                  "${data.name} - ${data.city} - ${data.date!.month.toString()}/${data.date!.day.toString()}/${data.date!.year.toString()}",
                  style: const TextStyle(fontWeight: FontWeight.bold)
                ),
                const SizedBox(width: 20),
                Text(
                  data.stars!.toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
                const Icon(Icons.star),
                const SizedBox(width: 20),
                IconButton(
                  iconSize: 20,
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    onEdit(data.id);
                  },
                ),
                IconButton(
                  iconSize: 20,
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    onDelete(data.id);
                  },
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                Text(
                  data.headline!.toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold)
                )
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                Text(data.description!.toString())
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// A form for creating a new review entry or editing an existing one
class ReviewEntryForm extends StatefulWidget {
  const ReviewEntryForm({super.key, required this.initialData, required this.onCancel, required this.onSubmit});

  final ReviewModel initialData;
  final void Function(int) onCancel;
  final void Function(int, ReviewModel) onSubmit;

  @override
  ReviewEntryFormState createState() {
    return ReviewEntryFormState();
  }
}

class ReviewEntryFormState extends State<ReviewEntryForm> {
  final List<int> starList = <int>[1, 2, 3, 4, 5];
  final _formKey = GlobalKey<FormState>();
  ReviewModel? newData;

  @override
  Widget build(BuildContext context) {
    newData ??= widget.initialData;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Name',
            ),
            initialValue: newData?.name ?? "",
            onChanged: (newValue) {
              newData!.name = newValue;
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter the restaurant name';
              }
              return null;
          }),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'City',
            ),
            initialValue: newData?.city ?? "",
            onChanged: (newValue) {
              newData!.city = newValue;
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter the city name';
              }
              return null;
          },),
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
                return null;
          },),
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
              return null;
            },),
          Row(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 16, 16, 0),
              child: ElevatedButton(
                onPressed: () {
                  widget.onCancel.call(widget.initialData.id);
                },
                child: const Text('Cancel'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 0, 0),
              child: ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState?.validate() ?? false) {
                    newData!.date = DateTime.now();
                    // Create a new version of the review with the new form data
                    widget.onSubmit.call(newData!.id, newData!);
                  }
                },
                child: const Text('Submit'),
              ),
            ),
          ],),
        ],
      ),
    );
  }
}

final reviewsProvider = StateNotifierProvider<ReviewsNotifier, List<ReviewModel>>((ref) {
  return ReviewsNotifier();
});

// The review list state management with Riverpod
class ReviewsNotifier extends StateNotifier<List<ReviewModel>> {
  ReviewsNotifier() : super([]) {
    loadFromDatabase();
  }
  int nextId = 1;

  void loadFromDatabase() {
    FirebaseFirestore.instance.collection("reviews")
    .where('uid', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
    .orderBy('date', descending: true)
    .get()
    .then((s) {
      List<ReviewModel> newReviews = [];
      for(var d in s.docs) {
        newReviews.add(ReviewModel(nextId++, false, false, d.id, d.data()));
      }
      state = newReviews;
    })
    .catchError((error) {
      state = [];
    });
  }

  void beginReview() {
    // Start a new review in editing mode at the top if not already there
    if(state.isEmpty || !state[0].isEditing) {
      state = [ReviewModel(nextId++, true, true, null, {}), ...state];
    }
  }

  void cancelReviewEdit(int id) {
    for(int i = 0; i < state.length; i++) {
      if(state[i].id == id) {
        if(state[i].isNew) {
          // Just remove cancelled new reviews
          deleteReview(id);
        } else {
          // Change the edit flag
          state[i].isEditing = false;
        }
      }
    }
    // Force state update
    state = [...state];
  }

  void submitReviewEdit(int id, ReviewModel m) {
    for(int i = 0; i < state.length; i++) {
      if(state[i].id == id) {
        var newData = {
          "uid": FirebaseAuth.instance.currentUser!.uid,
          "name": m.name,
          "city": m.city,
          "date": m.date,
          "stars": m.stars,
          "headline": m.headline,
          "description": m.description
        };
        if(state[i].isNew) {
          // Add the new review to the database
          FirebaseFirestore.instance.collection("reviews").add(newData);
        } else {
          // Update the existing review in the database
          FirebaseFirestore.instance.collection("reviews").doc(m.docId).set(newData);
        }
        // Switch from form panel to view panel
        m.isNew = false;
        m.isEditing = false;
        state[i] = m;
      }
    }
    // Force state update
    state = [...state];
  }

  void beginReviewEdit(int id) {
    for(int i = 0; i < state.length; i++) {
      if(state[i].id == id) {
        // Change the edit flag
        final s = state[i];
        s.isEditing = true;
        state[i] = s;
      }
    }
    // Force state update
    state = [...state];
  }

  void deleteReview(int id) {
    for(int i = 0; i < state.length; i++) {
      if(state[i].id == id) {
        if(!state[i].isNew) {
          // Delete existing reviews
          FirebaseFirestore.instance.collection("reviews").doc(state[i].docId).delete();
        }
        state = [...state.where((element) {return element.id != id;})];
      }
    }
  }
}

// An interactive list of reviews and review forms
class ReviewsList extends ConsumerWidget {
  const ReviewsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(reviewsProvider);
    return ListView.builder(
      itemCount: reviews.length,
      itemBuilder: (context, index) {
        final review = reviews[index].copyWith();
        if(review.isEditing) {
          return Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.grey,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(20))
            ),
            child: ReviewEntryForm(
              initialData: review,
              onCancel: (int id) {ref.read(reviewsProvider.notifier).cancelReviewEdit(id);},
              onSubmit: (int id, ReviewModel m) {ref.read(reviewsProvider.notifier).submitReviewEdit(id, m);}));
        }
        return Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
              border: Border.all(
                color: Colors.grey,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(20))
          ),
          child: ReviewEntry(
            data: review,
            onEdit: (int id) {ref.read(reviewsProvider.notifier).beginReviewEdit(id);},
            onDelete: (int id) {ref.read(reviewsProvider.notifier).deleteReview(id);}));
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
      body: Container(padding: const EdgeInsets.all(5), child: const ReviewsList()),
    );
  }
}
