// Copyright 2020 LeanCode Sp. z o.o.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:oauth2/oauth2.dart' as oauth2;

import 'credentials_storage/credentials_storage.dart';
import 'oauth_settings.dart';
import 'refresh_exception.dart';
import 'strategies/authorization_strategy.dart';
import 'utils.dart';

/// Signature for callbacks that report that the underlying credentials have
/// changed.
typedef CredentialsChangedCallback = void Function(oauth2.Credentials);

typedef _LoggerCallback = void Function(String);

// ignore: avoid_print
void _defaultPrintLogger(String message) => print('[LoginClient] $message');

/// An implementation of an OAuth2 client that also manages storing
/// the obtained credentials and restoring/refreshing them when needed.
class LoginClient extends http.BaseClient {
  /// Creates an [http.Client] that is compliant with OAuth2.
  ///
  /// The `oAuthSettings` stores authorization related settings, like
  /// the client's identifier and secret or the authorization's endpoint.
  ///
  /// The `credentialsStorage` handles saving and retrieving the authorization
  /// credentials.
  ///
  /// The `httpClient` is an [http.Client] that's used as a parent for the
  /// authorized HTTP client. It is also used for sending unauthorized requests.
  /// Defaults to [http.Client].
  ///
  /// The `credentialsChangedCallback` is where you can listen for changes
  /// to the credentials, e.g. for updating the displayed permissions in
  /// the app or showing when the user will be logged out.
  ///
  /// The `logger` is a simple callback used for logging debug information
  /// that may be helpful. Defaults to printing with a `[LoginClient]` prefix.
  ///
  /// Make sure to call [initialize] after instantiating the [LoginClient]
  /// to correctly restore saved credentials from the `credentialsStorage`.
  ///
  /// See also:
  /// - [InMemoryCredentialsStorage]
  LoginClient({
    @required OAuthSettings oAuthSettings,
    @required CredentialsStorage credentialsStorage,
    http.Client httpClient,
    CredentialsChangedCallback credentialsChangedCallback,
    _LoggerCallback logger = _defaultPrintLogger,
  })  : assert(oAuthSettings != null),
        assert(credentialsStorage != null),
        assert(logger != null),
        _oAuthSettings = oAuthSettings,
        _httpClient = httpClient ?? http.Client(),
        _credentialsStorage = credentialsStorage,
        _credentialsChangedCallback = credentialsChangedCallback,
        _logger = logger;

  final OAuthSettings _oAuthSettings;
  final CredentialsStorage _credentialsStorage;
  final http.Client _httpClient;
  final CredentialsChangedCallback _credentialsChangedCallback;
  final _LoggerCallback _logger;

  oauth2.Client _oAuthClient;

  /// Whether this [LoginClient] is authorized or not.
  bool get loggedIn => _oAuthClient != null;

  /// Restores saved credentials from the credentials storage.
  Future<void> initialize() async {
    final credentials = await _credentialsStorage.read();
    if (credentials != null) {
      _oAuthClient = buildOAuth2ClientFromCredentials(
        credentials,
        oAuthSettings: _oAuthSettings,
        httpClient: _httpClient,
        onCredentialsRefreshed: _onCredentialsRefreshed,
      );
    }

    _credentialsChangedCallback?.call(credentials);

    if (credentials != null) {
      _logger('Successfully initialized with credentials.');
    } else {
      _logger('Successfully initialized with no credentials.');
    }
  }

  /// Authorizes the [LoginClient] using the passed `strategy`.
  ///
  /// This method will log the [LoginClient] out on the authorization failure.
  Future<void> logIn(AuthorizationStrategy strategy) async {
    try {
      _oAuthClient?.close();
      _oAuthClient = await strategy.execute(
        _oAuthSettings,
        _httpClient,
        _onCredentialsRefreshed,
      );

      _credentialsChangedCallback?.call(_oAuthClient.credentials);
      await _credentialsStorage.save(_oAuthClient.credentials);

      _logger('Successfully logged in and saved the credentials.');
    } on oauth2.AuthorizationException {
      await _logOutInternal();
      _logger('An error while logging in occured, '
          'successfully logged out and cleared credentials.');
      rethrow;
    }
  }

  /// Refreshes the currently used credentials.
  ///
  /// `newScopes` can be also provided to obtain a different set of scopes
  /// after the refreshing. If left null, old scopes are used.
  ///
  /// This method will log the [LoginClient] out on the authorization failure.
  ///
  /// See also:
  /// - https://tools.ietf.org/html/rfc6749#section-6
  Future<void> refresh([List<String> newScopes]) async {
    if (_oAuthClient == null) {
      throw const RefreshException(
        'Cannot refresh unauthorized client. Login first.',
      );
    }

    try {
      _oAuthClient = await _oAuthClient.refreshCredentials(newScopes);
    } on oauth2.AuthorizationException {
      await _logOutInternal();
      _logger('An error while force refreshing occured, '
          'successfully logged out and cleared credentials.');
      rethrow;
    }
  }

  /// Logs the [LoginClient] out. Also removes the credentials from
  /// the credentials storage.
  Future<void> logOut() async {
    await _logOutInternal();
    _logger('Successfully logged out and cleared the credentials.');
  }

  Future<void> _logOutInternal() async {
    _credentialsChangedCallback?.call(null);
    await _credentialsStorage.clear();

    _oAuthClient?.close();
    _oAuthClient = null;
  }

  Future<void> _onCredentialsRefreshed(oauth2.Credentials credentials) async {
    _credentialsChangedCallback?.call(credentials);
    await _credentialsStorage.save(credentials);

    _logger('Successfully refreshed and saved the new credentials.');
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final client = _oAuthClient ?? _httpClient;

    http.StreamedResponse response;
    try {
      response = await client.send(request);
    } on oauth2.AuthorizationException {
      await _logOutInternal();
      _logger('An error while sending a request occured, '
          'successfully logged out and cleared credentials.');
      rethrow;
    }

    return response;
  }

  // ignore: use_setters_to_change_properties
  @visibleForTesting
  void setAuthorizedClient(oauth2.Client client) => _oAuthClient = client;
}