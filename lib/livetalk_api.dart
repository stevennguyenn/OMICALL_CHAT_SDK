import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_uploader/flutter_uploader.dart';
import 'package:http/http.dart' as http;
import 'package:livetalk_sdk/livetalk_file_utils.dart';
import 'package:livetalk_sdk/livetalk_string_utils.dart';
import 'dart:math' as math;
import 'entity/entity.dart';

class LiveTalkApi {
  LiveTalkApi._();

  static final instance = LiveTalkApi._();
  Map<String, String>? _sdkInfo;

  Map<String, dynamic>? get sdkInfo => _sdkInfo;
  final String _baseUrl = 'https://livetalk-v2-stg.omicrm.com/widget';

  Future<Map<String, dynamic>?> getConfig(String domainPbx) async {
    try {
      var headers = {'Content-Type': 'application/json'};
      var request = http.Request(
        'POST',
        Uri.parse('$_baseUrl/config/get/$domainPbx'),
      );
      request.body = json.encode({});
      request.headers.addAll(headers);
      http.StreamedResponse response = await request.send();
      if ((response.statusCode ~/ 100) > 2) {
        throw LiveTalkError(message: {"message": response.reasonPhrase});
      }
      if (response.statusCode == 200) {
        final data = await response.stream.bytesToString();
        final jsonData = json.decode(data);
        if (jsonData["status_code"] == -9999) {
          throw LiveTalkError(message: jsonData);
        }
        final payload = jsonData["payload"];
        final tentantId = payload["tenant_id"];
        final accessToken = payload["token"]["access_token"];
        final refreshToken = payload["token"]["refresh_token"];
        _sdkInfo = {
          "tenant_id": tentantId,
          "access_token": accessToken,
          "refresh_token": refreshToken,
        };
        return _sdkInfo;
      }
      return null;
    } catch (error) {
      rethrow;
    }
  }

  String get _uuid {
    return "$_randomString${DateTime.now().millisecondsSinceEpoch}";
  }

  String get _randomString {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXTZabcdefghiklmnopqrstuvwxyz';
    const maxRandom = chars.length;
    final list = List.generate(11, (index) {
      final rNum = math.Random().nextInt(maxRandom);
      return chars.substring(rNum, rNum + 1);
    });
    return list.join("");
  }

  Future<String?> createRoom({
    required Map<String, dynamic> body,
  }) async {
    try {
      var headers = {'Content-Type': 'application/json'};
      var request = http.Request(
        'POST',
        Uri.parse('$_baseUrl/new_room'),
      );
      request.body = json.encode(body);
      request.headers.addAll(headers);
      http.StreamedResponse response = await request.send();
      if ((response.statusCode ~/ 100) > 2) {
        throw LiveTalkError(message: {"message": response.reasonPhrase});
      }
      if (response.statusCode == 200) {
        final data = await response.stream.bytesToString();
        final jsonData = json.decode(data);
        if (jsonData["status_code"] == -9999) {
          throw LiveTalkError(message: jsonData);
        }
        final payload = jsonData["payload"];
        _sdkInfo!["uuid"] = payload["conversation"]["uuid"];
        _sdkInfo!["room_id"] = payload["conversation"]["_id"];
        _sdkInfo!["access_token"] = payload["login_token"]["access_token"];
        _sdkInfo!["refresh_token"] = payload["login_token"]["refresh_token"];
        return payload["conversation"]["_id"];
      }
      return null;
    } catch (error) {
      rethrow;
    }
  }

  Future<LiveTalkRoomEntity?> getCurrentRoom() async {
    try {
      if (sdkInfo == null) {
        throw LiveTalkError(message: {"message": "empty_info"});
      }
      var headers = {
        'Content-Type': 'application/json',
        'Authorization': "Bearer ${_sdkInfo!["access_token"] as String}",
      };
      var request = http.Request(
        'GET',
        Uri.parse('$_baseUrl//guest/room/${_sdkInfo!["room_id"]}'),
      );
      request.headers.addAll(headers);
      http.StreamedResponse response = await request.send();
      if ((response.statusCode ~/ 100) > 2) {
        throw LiveTalkError(message: {"message": response.reasonPhrase});
      }
      if (response.statusCode == 200) {
        final data = await response.stream.bytesToString();
        final jsonData = json.decode(data);
        if (jsonData["status_code"] == -9999) {
          throw LiveTalkError(message: jsonData);
        }
        final payload = jsonData["payload"];
        return LiveTalkRoomEntity.fromJson(payload);
      }
      return null;
    } catch (error) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> sendMessage(LiveTalkSendingMessage message) async {
    final messageTxt = message.message;
    final quoteId = message.quoteId;
    final sticker = message.sticker;
    final paths = message.paths;
    if (sticker != null) {
      return _sendSticker(sticker: sticker);
    }
    if (messageTxt != null) {
      return _sendText(message: messageTxt, quoteId: quoteId);
    }
    if (paths != null) {
      return _sendFiles(paths: paths);
    }
    return null;
  }

  Future<Map<String, dynamic>?> _sendSticker({
    required String sticker,
  }) async {
    if (sdkInfo == null) {
      throw LiveTalkError(message: {"message": "empty_info"});
    }
    var headers = {
      'Content-Type': 'application/json',
      'Authorization': "Bearer ${_sdkInfo!["access_token"] as String}",
    };
    var request = http.Request(
      'POST',
      Uri.parse('$_baseUrl/message/sticker/guest_send'),
    );
    final body = {
      "type": "guest",
      "url": sticker,
      "uuid":_uuid,
      "room_id": _sdkInfo!["room_id"],
    };
    request.body = json.encode(body);
    request.headers.addAll(headers);
    http.StreamedResponse response = await request.send();
    if ((response.statusCode ~/ 100) > 2) {
      throw LiveTalkError(message: {"message": response.reasonPhrase});
    }
    if (response.statusCode == 200) {
      final data = await response.stream.bytesToString();
      final jsonData = json.decode(data);
      if (jsonData["status_code"] == -9999) {
        throw LiveTalkError(message: jsonData);
      }
      return jsonData["payload"];
    }
    return null;
  }

  Future<Map<String, dynamic>?> _sendText({
    required String message,
    String? quoteId,
  }) async {
    if (sdkInfo == null) {
      throw LiveTalkError(message: {"message": "empty_info"});
    }
    if (message.trim().isEmpty) {
      throw LiveTalkError(message: {"message": "empty_text"});
    }
    var headers = {
      'Content-Type': 'application/json',
      'Authorization': "Bearer ${_sdkInfo!["access_token"] as String}",
    };
    var request = http.Request(
      'POST',
      Uri.parse('$_baseUrl/message/guest_send_message'),
    );
    final body = {
      "content": message.encode,
      "uuid": _uuid,
      "room_id": _sdkInfo!["room_id"],
    };
    if (quoteId != null) {
      body["quote_id"] = quoteId;
    }
    request.body = json.encode(body);
    request.headers.addAll(headers);
    http.StreamedResponse response = await request.send();
    if ((response.statusCode ~/ 100) > 2) {
      throw LiveTalkError(message: {"message": response.reasonPhrase});
    }
    if (response.statusCode == 200) {
      final data = await response.stream.bytesToString();
      final jsonData = json.decode(data);
      if (jsonData["status_code"] == -9999) {
        throw LiveTalkError(message: jsonData);
      }
      return jsonData["payload"];
    }
    return null;
  }

  Future<bool> actionOnMessage({
    required String content,
    required String id,
    required String action,
  }) async {
    if (sdkInfo == null) {
      throw LiveTalkError(message: {"message": "empty_info"});
    }
    var headers = {
      'Content-Type': 'application/json',
      'Authorization': "Bearer ${_sdkInfo!["access_token"] as String}",
    };
    var request = http.Request(
      'POST',
      Uri.parse('$_baseUrl/guest/message/sender_action'),
    );
    request.body = json.encode({
      "content": content,
      "uuid": _uuid,
      "ref_id": id,
      "room_id": _sdkInfo!["room_id"],
      "action": action,
    });
    request.headers.addAll(headers);
    http.StreamedResponse response = await request.send();
    if ((response.statusCode ~/ 100) > 2) {
      throw LiveTalkError(message: {"message": response.reasonPhrase});
    }
    if (response.statusCode == 200) {
      final data = await response.stream.bytesToString();
      final jsonData = json.decode(data);
      if (jsonData["status_code"] == -9999) {
        throw LiveTalkError(message: jsonData);
      }
      return true;
    }
    return false;
  }

  Future<Map<String, dynamic>?> _sendFiles({required List<String> paths}) async {
    if (sdkInfo == null) {
      throw LiveTalkError(message: {"message": "empty_info"});
    }
    if (paths.isEmpty == true) {
      throw LiveTalkError(message: {"message": "empty_paths"});
    }
    if (paths.length > 6) {
      throw LiveTalkError(message: {"message": "out_of_limitation"});
    }
    final files = paths.map((e) => File(e)).toList();
    final totalSize = files.fold<double>(
      0.0,
      (previousValue, element) => previousValue + element.fileSize,
    );
    if (totalSize > 50) {
      throw LiveTalkError(message: {"message": "limit_50mb"});
    }
    var headers = {
      'Authorization': "Bearer ${_sdkInfo!["access_token"] as String}",
    };
    List<FileItem> fileItems = [];
    for (var path in paths) {
      // File file = File(path);
      fileItems.add(FileItem(path: path, field: "files"));
    }

    final taskId = await FlutterUploader().enqueue(
      MultipartFormDataUpload(
        url: '$_baseUrl/message/guest_send_media', // required: url to upload to
        files: fileItems, // r
        method: UploadMethod.POST, // HTTP method  (POST or PUT or PATCH)
        headers: headers,
        tag: 'upload',
        data: {
          "uuid": _uuid,
          "room_id": _sdkInfo!["room_id"] ?? "",
        },
      ),
    );
    return {
      "task_id": taskId,
    };
    // http.StreamedResponse response = await request.send().timeout(
    //   const Duration(seconds: 600),
    //   onTimeout: () {
    //     throw throw LiveTalkError(message: "timeout");
    //   },
    // );
    // if ((response.statusCode ~/ 100) > 2) {
    //   throw LiveTalkError(message: {"message": response.reasonPhrase});
    // }
    // if (response.statusCode == 200) {
    //   final data = await response.stream.bytesToString();
    //   final jsonData = json.decode(data);
    //   if (jsonData["status_code"] == -9999) {
    //     throw LiveTalkError(message: jsonData);
    //   }
    //   return jsonData["payload"];
    // }
    // return null;
  }

  Future<List<LiveTalkMessageEntity>> getMessageHistory({
    required int page,
    int size = 15,
  }) async {
    if (sdkInfo == null) {
      throw LiveTalkError(message: {"message": "empty_info"});
    }
    var headers = {
      'Content-Type': 'application/json',
      'Authorization': "Bearer ${_sdkInfo!["access_token"] as String}",
    };
    var request = http.Request(
      'POST',
      Uri.parse('$_baseUrl/message/search_for_guest?page=$page&size=$size'),
    );
    request.body = json.encode({});
    request.headers.addAll(headers);
    http.StreamedResponse response = await request.send();
    if ((response.statusCode ~/ 100) > 2) {
      throw LiveTalkError(message: {"message": response.reasonPhrase});
    }
    if (response.statusCode == 200) {
      final data = await response.stream.bytesToString();
      final jsonData = json.decode(data);
      if (jsonData["status_code"] == -9999) {
        throw LiveTalkError(message: jsonData);
      }
      final items = jsonData["payload"]["items"] as List;
      return List.generate(items.length,
          (index) => LiveTalkMessageEntity.fromJson(items[index]));
    }
    return [];
  }

  Future<bool> removeMessage({required String id}) async {
    if (sdkInfo == null) {
      throw LiveTalkError(message: {"message": "empty_info"});
    }
    var headers = {
      'Content-Type': 'application/json',
      'Authorization': "Bearer ${_sdkInfo!["access_token"] as String}",
    };
    var request = http.Request(
      'POST',
      Uri.parse('$_baseUrl/guest/message/remove'),
    );
    request.body = json.encode({
      "room_id": _sdkInfo!["room_id"] ?? "",
      "message_id": id,
    });
    request.headers.addAll(headers);
    http.StreamedResponse response = await request.send();
    if ((response.statusCode ~/ 100) > 2) {
      throw LiveTalkError(message: {"message": response.reasonPhrase});
    }
    if (response.statusCode == 200) {
      final data = await response.stream.bytesToString();
      final jsonData = json.decode(data);
      if (jsonData["status_code"] == -9999) {
        throw LiveTalkError(message: jsonData);
      }
      return true;
    }
    return false;
  }

  Future<LiveTalkGeoEntity?> getGeo() async {
    var headers = {
      'Content-Type': 'application/json',
    };
    var request = http.Request(
      'GET',
      Uri.parse('$_baseUrl/geo'),
    );
    request.body = json.encode({});
    request.headers.addAll(headers);
    http.StreamedResponse response = await request.send();
    if ((response.statusCode ~/ 100) > 2) {
      throw LiveTalkError(message: {"message": response.reasonPhrase});
    }
    if (response.statusCode == 200) {
      final data = await response.stream.bytesToString();
      final jsonData = json.decode(data);
      if (jsonData["status_code"] == -9999) {
        throw LiveTalkError(message: jsonData);
      }
      final payload = json.decode(jsonData["payload"]);
      final result = LiveTalkGeoEntity.fromJson(payload);
      return result;
    }
    return null;
  }
}
