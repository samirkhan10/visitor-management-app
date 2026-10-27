import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../core/app_exception.dart';
import '../models/visitor.dart';
import 'visitor_repository.dart';

class ApiVisitorRepository implements VisitorRepository {
  ApiVisitorRepository({String baseUrl = ApiConfig.baseUrl, http.Client? client})
    : _baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
      _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  static const _headers = {'Content-Type': 'application/json', 'Accept': 'application/json'};

  Uri _visitorsUri([String? id]) {
    final path = id == null ? 'visitors' : 'visitors/${Uri.encodeComponent(id)}';
    return Uri.parse('$_baseUrl/$path');
  }

  @override
  Future<List<Visitor>> fetchVisitors() async {
    final body = await _send(() => _client.get(_visitorsUri(), headers: _headers));
    if (body is! List) {
      throw const AppException('Received an unexpected response from the server.');
    }
    return body.whereType<Map<String, dynamic>>().map(Visitor.fromJson).toList();
  }

  @override
  Future<Visitor> fetchVisitor(String id) async {
    final body = await _send(
      () => _client.get(_visitorsUri(id), headers: _headers),
      notFoundMessage: 'No visitor found with ID $id.',
    );
    return _parseVisitor(body);
  }

  @override
  Future<Visitor> createVisitor(VisitorDraft draft) async {
    final body = await _send(
      () => _client.post(
        _visitorsUri(),
        headers: _headers,
        body: jsonEncode(draft.toCreateJson(DateTime.now())),
      ),
    );
    return _parseVisitor(body);
  }

  @override
  Future<Visitor> updateVisitor(String id, Map<String, dynamic> changes) async {
    // MockAPI merges the fields sent in a PUT, so partial bodies work like PATCH.
    final body = await _send(
      () => _client.put(_visitorsUri(id), headers: _headers, body: jsonEncode(changes)),
      notFoundMessage: 'This visitor no longer exists.',
    );
    return _parseVisitor(body);
  }

  @override
  Future<void> deleteVisitor(String id) async {
    await _send(
      () => _client.delete(_visitorsUri(id), headers: _headers),
      notFoundMessage: 'This visitor was already deleted.',
    );
  }

  Visitor _parseVisitor(dynamic body) {
    if (body is! Map<String, dynamic> || body['id'] == null) {
      throw const AppException('Received an invalid visitor record from the server.');
    }
    return Visitor.fromJson(body);
  }

  Future<dynamic> _send(
    Future<http.Response> Function() request, {
    String notFoundMessage = 'The requested record was not found.',
  }) async {
    if (!ApiConfig.isConfigured) {
      throw const AppException(
        'API base URL is not set. Add your MockAPI URL in lib/core/api_config.dart.',
      );
    }

    final http.Response response;
    try {
      response = await request().timeout(ApiConfig.timeout);
    } on TimeoutException {
      throw const AppException('The server is taking too long to respond. Please try again.');
    } on SocketException {
      throw const AppException('No internet connection. Check your network and try again.');
    } on http.ClientException {
      throw const AppException('Could not connect to the server. Please try again.');
    }

    final statusCode = response.statusCode;
    if (statusCode == 404) {
      throw AppException(notFoundMessage, statusCode: statusCode);
    }
    if (statusCode == 429) {
      throw AppException('Too many requests. Wait a moment and retry.', statusCode: statusCode);
    }
    if (statusCode >= 500) {
      throw AppException(
        'Server error ($statusCode). Please try again later.',
        statusCode: statusCode,
      );
    }
    if (statusCode < 200 || statusCode >= 300) {
      throw AppException('Request failed with status $statusCode.', statusCode: statusCode);
    }

    if (response.body.trim().isEmpty) return null;

    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw const AppException('Received an invalid response from the server.');
    }
  }
}
