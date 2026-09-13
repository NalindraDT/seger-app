import 'package:flutter_test/flutter_test.dart';
import 'package:pltuapp/widgets/app_network_image.dart';

void main() {
  test('sizedImageUrl appends ?w= correctly', () {
    expect(
      sizedImageUrl(
        'https://host/api/v1/storage/public/pltu-files/activity-proofs/x.webp',
        136,
      ),
      'https://host/api/v1/storage/public/pltu-files/activity-proofs/x.webp?w=136',
    );
    expect(
      sizedImageUrl('https://ui-avatars.com/api/?name=A', 64),
      'https://ui-avatars.com/api/?name=A&w=64',
    );
    expect(sizedImageUrl('https://h/i.png#frag', 32), 'https://h/i.png?w=32#frag');
    expect(sizedImageUrl('', 100), '');
    expect(sizedImageUrl('data:image/png;base64,AAAA', 100),
        'data:image/png;base64,AAAA');
  });

  test('sizedImagePx doubles css width and clamps to 32..2048', () {
    expect(sizedImagePx(68), 136);
    expect(sizedImagePx(1), 32);
    expect(sizedImagePx(5000), 2048);
  });
}
