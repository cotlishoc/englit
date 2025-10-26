class UserWordModel {
  final String wordId;
  final String status; // "изучаю", "изучено"

  UserWordModel({required this.wordId, required this.status});

  factory UserWordModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return UserWordModel(
      wordId: documentId,
      status: data['status'] ?? 'изучаю',
    );
  }
}