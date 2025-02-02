import 'dart:async';

import 'package:diox/diox.dart';
import 'package:test/test.dart';

import 'mock/adapters.dart';

class MyInterceptor extends Interceptor {
  int requestCount = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requestCount++;
    return super.onRequest(options, handler);
  }
}

void main() {
  group('#test Request Interceptor', () {
    Dio dio;

    test('#test interceptor chain', () async {
      dio = Dio();
      dio.options.baseUrl = EchoAdapter.mockBase;
      dio.httpClientAdapter = EchoAdapter();
      dio.interceptors
        ..add(InterceptorsWrapper(
          onRequest: (reqOpt, handler) {
            switch (reqOpt.path) {
              case '/resolve':
                handler.resolve(Response(requestOptions: reqOpt, data: 1));
                break;
              case '/resolve-next':
                handler.resolve(
                  Response(requestOptions: reqOpt, data: 2),
                  true,
                );
                break;
              case '/resolve-next/always':
                handler.resolve(
                  Response(requestOptions: reqOpt, data: 2),
                  true,
                );
                break;
              case '/resolve-next/reject':
                handler.resolve(
                  Response(requestOptions: reqOpt, data: 2),
                  true,
                );
                break;
              case '/resolve-next/reject-next':
                handler.resolve(
                  Response(requestOptions: reqOpt, data: 2),
                  true,
                );
                break;
              case '/reject':
                handler.reject(DioError(requestOptions: reqOpt, error: 3));
                break;
              case '/reject-next':
                handler.reject(
                  DioError(requestOptions: reqOpt, error: 4),
                  true,
                );
                break;
              case '/reject-next/reject':
                handler.reject(
                  DioError(requestOptions: reqOpt, error: 5),
                  true,
                );
                break;
              case '/reject-next-response':
                handler.reject(
                  DioError(requestOptions: reqOpt, error: 5),
                  true,
                );
                break;
              default:
                handler.next(reqOpt); //continue
            }
          },
          onResponse: (response, ResponseInterceptorHandler handler) {
            final options = response.requestOptions;
            switch (options.path) {
              case '/resolve':
                throw 'unexpected1';
              case '/resolve-next':
                response.data++;
                handler.resolve(response); //3
                break;
              case '/resolve-next/always':
                response.data++;
                handler.next(response); //3
                break;
              case '/resolve-next/reject':
                handler.reject(DioError(
                  requestOptions: options,
                  error: '/resolve-next/reject',
                ));
                break;
              case '/resolve-next/reject-next':
                handler.reject(
                  DioError(requestOptions: options, error: ''),
                  true,
                );
                break;
              default:
                handler.next(response); //continue
            }
          },
          onError: (err, handler) {
            if (err.requestOptions.path == '/reject-next-response') {
              handler.resolve(Response(
                requestOptions: err.requestOptions,
                data: 100,
              ));
            } else if (err.requestOptions.path == '/resolve-next/reject-next') {
              handler.next(err.copyWith(error: 1));
            } else {
              if (err.requestOptions.path == '/reject-next/reject') {
                handler.reject(err);
              } else {
                int count = err.error as int;
                count++;
                handler.next(err.copyWith(error: count));
              }
            }
          },
        ))
        ..add(InterceptorsWrapper(
          onRequest: (options, handler) => handler.next(options),
          onResponse: (response, handler) {
            final options = response.requestOptions;
            switch (options.path) {
              case '/resolve-next/always':
                response.data++;
                handler.next(response); //4
                break;
              default:
                handler.next(response); //continue
            }
          },
          onError: (err, handler) {
            if (err.requestOptions.path == '/resolve-next/reject-next') {
              int count = err.error as int;
              count++;
              handler.next(err.copyWith(error: count));
            } else {
              int count = err.error as int;
              count++;
              handler.next(err.copyWith(error: count));
            }
          },
        ));
      Response response = await dio.get('/resolve');
      assert(response.data == 1);
      response = await dio.get('/resolve-next');

      assert(response.data == 3);

      response = await dio.get('/resolve-next/always');
      assert(response.data == 4);

      response = await dio.post('/post', data: 'xxx');
      assert(response.data == 'xxx');

      response = await dio.get('/reject-next-response');
      assert(response.data == 100);

      expect(
        dio.get('/reject').catchError((e) => throw e.error as num),
        throwsA(3),
      );

      expect(
        dio.get('/reject-next').catchError((e) => throw e.error as num),
        throwsA(6),
      );

      expect(
        dio.get('/reject-next/reject').catchError((e) => throw e.error as num),
        throwsA(5),
      );

      expect(
        dio
            .get('/resolve-next/reject')
            .catchError((e) => throw e.error as Object),
        throwsA('/resolve-next/reject'),
      );

      expect(
        dio
            .get('/resolve-next/reject-next')
            .catchError((e) => throw e.error as num),
        throwsA(2),
      );
    });

    test('unexpected error', () async {
      final dio = Dio();
      dio.options.baseUrl = EchoAdapter.mockBase;
      dio.httpClientAdapter = EchoAdapter();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (reqOpt, handler) {
            if (reqOpt.path == '/error') {
              throw 'unexpected';
            }
            handler.next(reqOpt.copyWith(path: '/xxx'));
          },
          onError: (err, handler) {
            handler.next(err.copyWith(error: 'unexpected error'));
          },
        ),
      );

      expect(
        dio.get('/error').catchError((e) => throw e.error as String),
        throwsA('unexpected error'),
      );

      expect(
        dio.get('/').then((e) => throw e.requestOptions.path),
        throwsA('/xxx'),
      );
    });

    test('#test request interceptor', () async {
      dio = Dio();
      dio.options.baseUrl = MockAdapter.mockBase;
      dio.httpClientAdapter = MockAdapter();
      dio.interceptors.add(InterceptorsWrapper(onRequest: (
        RequestOptions options,
        RequestInterceptorHandler handler,
      ) {
        switch (options.path) {
          case '/fakepath1':
            handler.resolve(
              Response(
                requestOptions: options,
                data: 'fake data',
              ),
            );
            break;
          case '/fakepath2':
            dio
                .get('/test')
                .then(handler.resolve)
                .catchError((e) => handler.reject(e as DioError));
            break;
          case '/fakepath3':
            handler.reject(DioError(
              requestOptions: options,
              error: 'test error',
            ));
            break;
          case '/fakepath4':
            handler.reject(DioError(
              requestOptions: options,
              error: 'test error',
            ));
            break;
          case '/test?tag=1':
            {
              dio.get('/token').then((response) {
                options.headers['token'] = response.data['data']['token'];
                handler.next(options);
              });
              break;
            }
          default:
            handler.next(options); //continue
        }
      }));

      Response response = await dio.get('/fakepath1');
      expect(response.data, 'fake data');

      response = await dio.get('/fakepath2');
      expect(response.data['errCode'], 0);

      expect(
        dio.get('/fakepath3'),
        throwsA(
          isA<DioError>()
              .having((e) => e.message, 'message', null)
              .having((e) => e.type, 'error type', DioErrorType.unknown),
        ),
      );
      expect(
        dio.get('/fakepath4'),
        throwsA(
          isA<DioError>()
              .having((e) => e.message, 'message', null)
              .having((e) => e.type, 'error type', DioErrorType.unknown),
        ),
      );

      response = await dio.get('/test');
      expect(response.data['errCode'], 0);
      response = await dio.get('/test?tag=1');
      expect(response.data['errCode'], 0);
    });
  });

  group('#test response interceptor', () {
    Dio dio;
    test('#test Response Interceptor', () async {
      const urlNotFound = '/404/';
      const urlNotFound1 = '${urlNotFound}1';
      const urlNotFound2 = '${urlNotFound}2';
      const urlNotFound3 = '${urlNotFound}3';

      dio = Dio();
      dio.httpClientAdapter = MockAdapter();
      dio.options.baseUrl = MockAdapter.mockBase;

      dio.interceptors.add(InterceptorsWrapper(
        onResponse: (response, handler) {
          response.data = response.data['data'];
          handler.next(response);
        },
        onError: (DioError e, ErrorInterceptorHandler handler) {
          if (e.response?.requestOptions != null) {
            switch (e.response!.requestOptions.path) {
              case urlNotFound:
                return handler.next(e);
              case urlNotFound1:
                return handler.resolve(
                  Response(
                    requestOptions: e.requestOptions,
                    data: 'fake data',
                  ),
                );
              case urlNotFound2:
                return handler.resolve(
                  Response(
                    data: 'fake data',
                    requestOptions: e.requestOptions,
                  ),
                );
              case urlNotFound3:
                return handler.next(
                  e.copyWith(
                    error: 'custom error info [${e.response!.statusCode}]',
                  ),
                );
            }
          }
          handler.next(e);
        },
      ));
      Response response = await dio.get('/test');
      expect(response.data['path'], '/test');
      expect(
        dio
            .get(urlNotFound)
            .catchError((e) => throw (e as DioError).response!.statusCode!),
        throwsA(404),
      );
      response = await dio.get('${urlNotFound}1');
      expect(response.data, 'fake data');
      response = await dio.get('${urlNotFound}2');
      expect(response.data, 'fake data');
      expect(
        dio.get('${urlNotFound}3').catchError((e) => throw e as DioError),
        throwsA(isA<DioError>()),
      );
    });
    test('multi response interceptor', () async {
      dio = Dio();
      dio.httpClientAdapter = MockAdapter();
      dio.options.baseUrl = MockAdapter.mockBase;
      dio.interceptors
        ..add(InterceptorsWrapper(
          onResponse: (resp, handler) {
            resp.data = resp.data['data'];
            handler.next(resp);
          },
        ))
        ..add(InterceptorsWrapper(
          onResponse: (resp, handler) {
            resp.data['extra_1'] = 'extra';
            handler.next(resp);
          },
        ))
        ..add(InterceptorsWrapper(
          onResponse: (resp, handler) {
            resp.data['extra_2'] = 'extra';
            handler.next(resp);
          },
        ));
      final resp = await dio.get('/test');
      expect(resp.data['path'], '/test');
      expect(resp.data['extra_1'], 'extra');
      expect(resp.data['extra_2'], 'extra');
    });
  });
  group('# test queued interceptors', () {
    test('test queued interceptor for requests ', () async {
      String? csrfToken;
      final dio = Dio();
      int tokenRequestCounts = 0;
      // dio instance to request token
      final tokenDio = Dio();
      dio.options.baseUrl = tokenDio.options.baseUrl = MockAdapter.mockBase;
      dio.httpClientAdapter = tokenDio.httpClientAdapter = MockAdapter();
      final myInter = MyInterceptor();
      dio.interceptors.add(myInter);
      dio.interceptors.add(QueuedInterceptorsWrapper(
        onRequest: (options, handler) {
          if (csrfToken == null) {
            tokenRequestCounts++;
            tokenDio.get('/token').then((d) {
              options.headers['csrfToken'] =
                  csrfToken = d.data['data']['token'] as String;
              handler.next(options);
            }).catchError((e) {
              handler.reject(e as DioError, true);
            });
          } else {
            options.headers['csrfToken'] = csrfToken;
            handler.next(options);
          }
        },
      ));

      int result = 0;
      void onResult(d) {
        if (tokenRequestCounts > 0) ++result;
      }

      await Future.wait([
        dio.get('/test?tag=1').then(onResult),
        dio.get('/test?tag=2').then(onResult),
        dio.get('/test?tag=3').then(onResult)
      ]);
      expect(tokenRequestCounts, 1);
      expect(result, 3);
      assert(myInter.requestCount > 0);
      dio.interceptors[0] = myInter;
      dio.interceptors.clear();
      assert(dio.interceptors.isEmpty == true);
    });

    test('test queued interceptors for error', () async {
      String? csrfToken;
      final dio = Dio();
      int tokenRequestCounts = 0;
      // dio instance to request token
      final tokenDio = Dio();
      dio.options.baseUrl = tokenDio.options.baseUrl = MockAdapter.mockBase;
      dio.httpClientAdapter = tokenDio.httpClientAdapter = MockAdapter();
      dio.interceptors.add(
        QueuedInterceptorsWrapper(
          onRequest: (opt, handler) {
            opt.headers['csrfToken'] = csrfToken;
            handler.next(opt);
          },
          onError: (error, handler) {
            // Assume 401 stands for token expired
            if (error.response?.statusCode == 401) {
              final options = error.response!.requestOptions;
              // If the token has been updated, repeat directly.
              if (csrfToken != options.headers['csrfToken']) {
                options.headers['csrfToken'] = csrfToken;
                //repeat
                dio
                    .fetch(options)
                    .then(handler.resolve)
                    .catchError((e) => handler.reject(e as DioError));
                return;
              }
              // update token and repeat
              tokenRequestCounts++;
              tokenDio.get('/token').then((d) {
                //update csrfToken
                options.headers['csrfToken'] =
                    csrfToken = d.data['data']['token'] as String;
              }).then((e) {
                //repeat
                dio
                    .fetch(options)
                    .then(handler.resolve)
                    .catchError((e) => handler.reject(e as DioError));
              });
            } else {
              handler.next(error);
            }
          },
        ),
      );

      int result = 0;
      void onResult(d) {
        if (tokenRequestCounts > 0) ++result;
      }

      await Future.wait([
        dio.get('/test-auth?tag=1').then(onResult),
        dio.get('/test-auth?tag=2').then(onResult),
        dio.get('/test-auth?tag=3').then(onResult)
      ]);
      expect(tokenRequestCounts, 1);
      expect(result, 3);
    });
  });
}
