class JobListing {
  final String title;
  final String organization;
  final String location;
  final String type; // Government, Private, Bank, Exam
  final String lastDate;
  final String vacancies;

  const JobListing({
    required this.title,
    required this.organization,
    required this.location,
    required this.type,
    required this.lastDate,
    required this.vacancies,
  });
}
