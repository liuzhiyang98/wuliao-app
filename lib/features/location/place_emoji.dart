/// 根据地点名称给出温柔的小图标，用于自动报备通知。
String placeEmoji(String? name) {
  if (name == null) return '📍';
  if (name.contains('家')) return '🏠';
  if (name.contains('公司') || name.contains('班') || name.contains('办公')) {
    return '🏢';
  }
  if (name.contains('学校') || name.contains('大学') || name.contains('教室')) {
    return '🎓';
  }
  if (name.contains('健身') || name.contains('运动')) return '🏋️';
  if (name.contains('咖啡') || name.contains('茶')) return '☕';
  return '📍';
}
