import 'dart:async';
import 'dart:io';

import 'package:diox/diox.dart';
import 'package:test/test.dart';

void main() {
  test('#test headers', () {
    final headers = Headers.fromMap({
      'set-cookie': ['k=v', 'k1=v1'],
      'content-length': ['200'],
      'test': ['1', '2'],
    });
    headers.add('SET-COOKIE', 'k2=v2');
    assert(headers.value('content-length') == '200');
    expect(Future(() => headers.value('test')), throwsException);
    assert(headers['set-cookie']?.length == 3);
    headers.remove('set-cookie', 'k=v');
    assert(headers['set-cookie']?.length == 2);
    headers.removeAll('set-cookie');
    assert(headers['set-cookie'] == null);
    final ls = [];
    headers.forEach((k, list) {
      ls.addAll(list);
    });
    assert(ls.length == 3);
    assert(headers.toString() == 'content-length: 200\ntest: 1\ntest: 2\n');
    headers.set('content-length', '300');
    assert(headers.value('content-length') == '300');
    headers.set('content-length', ['400']);
    assert(headers.value('content-length') == '400');

    final headers1 = Headers();
    headers1.set('xx', 'v');
    assert(headers1.value('xx') == 'v');
    headers1.clear();
    assert(headers1.map.isEmpty == true);
  });

  test('#send with an invalid URL', () async {
    await expectLater(
      Dio().get('http://http.invalid'),
      throwsA((e) => e is DioError && e.error is SocketException),
    );
  }, testOn: "vm");

  test('#cancellation', () async {
    final dio = Dio();
    final token = CancelToken();
    Timer(Duration(milliseconds: 10), () {
      token.cancel('cancelled');
      dio.httpClientAdapter.close(force: true);
    });

    final url = 'https://pub.dev';
    await expectLater(
      dio.get(url, cancelToken: token),
      throwsA((e) => e is DioError && CancelToken.isCancel(e)),
    );
  });

  test('#status error', () async {
    final dio = Dio()..options.baseUrl = 'https://httpbin.org/status/';
    await expectLater(
      dio.get('401'),
      throwsA((e) =>
          e is DioError &&
          e.type == DioErrorType.badResponse &&
          e.response!.statusCode == 401),
    );
    final r = await dio.get(
      '401',
      options: Options(validateStatus: (status) => true),
    );
    expect(r.statusCode, 401);
  });
}
