import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/network/dio_client.dart';

import 'models/chat_conversation.dart';
import 'models/chat_message.dart';

/// `/food/chat` — conversations with the ADMIN support desk, optionally
/// scoped to one order. Errors surface as the shared `ApiException` via the
/// app's dio interceptor, same as `SupportRepository`.
class ChatRepository {
  ChatRepository(this._dio);

  final Dio _dio;

  Future<ChatMessage> sendMessage({
    required String peerRole,
    String? peerId,
    String? orderId,
    required String text,
  }) async {
    final res = await _dio.post(
      '/food/chat/messages',
      data: {
        'peerRole': peerRole,
        'peerId': ?peerId,
        'orderId': ?orderId,
        'text': text,
      },
    );
    final body = res.data['data'] as Map<String, dynamic>? ?? res.data as Map<String, dynamic>;
    return ChatMessage.fromJson(body['message'] as Map<String, dynamic>);
  }

  Future<List<ChatConversation>> getConversations({String? orderId}) async {
    final res = await _dio.get(
      '/food/chat/conversations',
      queryParameters: {if (orderId != null && orderId.isNotEmpty) 'orderId': orderId},
    );
    final body = res.data['data'] as Map<String, dynamic>? ?? res.data as Map<String, dynamic>;
    final list = body['conversations'] as List<dynamic>? ?? [];
    return list.whereType<Map<String, dynamic>>().map(ChatConversation.fromJson).toList();
  }

  Future<ChatHistoryPage> getMessages({
    required String conversationId,
    int page = 1,
    int limit = 30,
  }) async {
    final res = await _dio.get(
      '/food/chat/messages',
      queryParameters: {'conversationId': conversationId, 'page': page, 'limit': limit},
    );
    final body = res.data['data'] as Map<String, dynamic>? ?? res.data as Map<String, dynamic>;
    final list = body['messages'] as List<dynamic>? ?? [];
    final pagination = body['pagination'] as Map<String, dynamic>? ?? {};
    return ChatHistoryPage(
      messages: list.whereType<Map<String, dynamic>>().map(ChatMessage.fromJson).toList(),
      page: (pagination['page'] as num?)?.toInt() ?? page,
      totalPages: (pagination['totalPages'] as num?)?.toInt() ?? 1,
    );
  }

  Future<int> markRead(String conversationId) async {
    final res = await _dio.patch('/food/chat/conversations/$conversationId/read');
    final body = res.data['data'] as Map<String, dynamic>? ?? res.data as Map<String, dynamic>;
    return (body['updated'] as num?)?.toInt() ?? 0;
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(dioProvider));
});
