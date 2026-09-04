enum DiffLineType { unchanged, added, removed }

class DiffLine {
  final DiffLineType type;
  final String text;
  final int? oldLineNum;
  final int? newLineNum;

  DiffLine(this.type, this.text, {this.oldLineNum, this.newLineNum});
}
