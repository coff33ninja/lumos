import 'package:flutter_test/flutter_test.dart';
import 'package:lumos_app/services/lumos_api.dart';

void main() {
  test('policy_denied with scope/action is humanized', () {
    const result = ApiCommandResult(
      ok: false,
      reason: 'policy_denied',
      message:
          'policy_denied action=shutdown: token_id=t1 scope=wake-only denied action=shutdown',
    );
    expect(
      result.readableMessage('fallback'),
      'Denied by token scope "wake-only" for action "shutdown"',
    );
  });

  test('supportsScopedPairing reads capabilities map', () {
    final status = {
      'capabilities': {'auth_token_scope': true}
    };
    expect(LumosApi.supportsScopedPairing(status), isTrue);
  });
}
