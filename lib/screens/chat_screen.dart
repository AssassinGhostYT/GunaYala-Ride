import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models/ride.dart';
import '../models/ride_request.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import '../services/rides_service.dart';

/// Chat del viaje. Solo los del viaje, solo en abordaje o en camino, y muere
/// cuando el viaje termina (regla 3).
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.ride, this.rideId, this.title});

  final Ride? ride;
  final String? rideId;
  final String? title;

  String get effectiveRideId => rideId ?? ride!.id;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final bool _closed = false;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _closed) return;
    final rides = context.read<RidesService>();
    final auth = context.read<AuthProvider>();
    _controller.clear();
    await rides.sendMessage(
      rideId: widget.effectiveRideId,
      senderName: auth.profile?.name ?? 'GunaYala',
      text: text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rides = context.read<RidesService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Chat del viaje'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(20),
          child: Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'El chat muere cuando termina el viaje',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ),
        ),
      ),
      body: StreamBuilder<Ride?>(
        stream: rides.watchRide(widget.effectiveRideId),
        builder: (context, snapshot) {
          final ride = snapshot.data;
          final open = ride != null && rides.chatOpenFor(ride);

          if (!open) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'El chat esta cerrado. Se abre en abordaje y en camino, y solo para '
                  'los de este viaje.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  stream: rides.watchChat(widget.effectiveRideId),
                  builder: (context, chatSnapshot) {
                    final messages = chatSnapshot.data ?? const <ChatMessage>[];
                    return ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        return Align(
                          alignment: message.mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: message.mine
                                  ? kCianOscuro
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!message.mine)
                                  Text(
                                    message.senderName,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black54,
                                    ),
                                  ),
                                Text(
                                  message.text,
                                  style: TextStyle(
                                    color: message.mine ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          maxLength: AppConfig.chatMaxLength,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: 'Escribe sin inventos graves',
                            counterText: '',
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _send,
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}