class Student {
  final String registerNo;
  final String name;
  final String dept;
  final String gender;
  final List<double>? faceEmbedding;

  Student({
    required this.registerNo,
    required this.name,
    required this.dept,
    required this.gender,
    this.faceEmbedding,
  });

  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      registerNo: map['register_no'] ?? '',
      name: map['name'] ?? '',
      dept: map['dept'] ?? '',
      gender: map['gender'] ?? '',
      faceEmbedding: map['face_embedding'] != null
          ? List<double>.from(map['face_embedding'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'register_no': registerNo,
      'name': name,
      'dept': dept,
      'gender': gender,
      if (faceEmbedding != null) 'face_embedding': faceEmbedding,
    };
  }
}
