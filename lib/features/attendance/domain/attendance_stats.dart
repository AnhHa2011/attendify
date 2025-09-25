class AttendanceStats {
  final int present, late, absent, excused;
  final double rate; // 0..1
  AttendanceStats(
    this.present,
    this.late,
    this.absent,
    this.excused,
    this.rate,
  );
}

AttendanceStats computeAgg(Iterable<String> statuses) {
  int present = 0, late = 0, absent = 0, excused = 0;
  for (final s in statuses) {
    switch (s) {
      case 'present':
        present++;
        break;
      case 'late':
        late++;
        break;
      case 'excused':
        excused++;
        break;
      default:
        absent++;
        break;
    }
  }
  final considered = present + late + absent; // bỏ excused khỏi mẫu số
  final double rate = considered == 0 ? 0 : (present + late) / considered;
  return AttendanceStats(present, late, absent, excused, rate);
}

AttendanceStats computeStats(List<String> statuses) {
  int p = 0, l = 0, a = 0, e = 0;
  for (final s in statuses) {
    switch (s) {
      case 'present':
        p++;
        break;
      case 'late':
        l++;
        break;
      case 'excused':
        e++;
        break;
      default:
        a++;
        break;
    }
  }
  final total = p + l + a; // bỏ excused khỏi mẫu số
  final double rate = total == 0 ? 0.0 : (p + l) / total;
  return AttendanceStats(p, l, a, e, rate);
}
