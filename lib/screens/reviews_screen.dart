import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ride.dart';
import '../models/ride_request.dart';
import '../providers/auth_provider.dart';
import '../rules/guards.dart';
import '../services/rides_service.dart';
import '../utils/formatters.dart';

/// Resenas. Se pueden ver las de un chofer o dejar una al terminar un viaje
/// (solo si el pasajero confirmo: regla 5).
class ReviewsScreen extends StatelessWidget {
  const ReviewsScreen({super.key, this.ride, this.driverId, this.name});

  final Ride? ride;
  final String? driverId;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final rides = context.read<RidesService>();
    final target = driverId ?? ride?.driverId ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(ride != null ? 'Tu resena' : 'Resenas de $name')),
      body: ride != null
          ? _LeaveReview(ride: ride!, rides: rides)
          : StreamBuilder<List<DriverReview>>(
              stream: rides.watchDriverReviews(target),
              builder: (context, snapshot) {
                final items = snapshot.data ?? const <DriverReview>[];
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (items.isEmpty) {
                  return const Center(child: Text('Todavia no hay resenas.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final review = items[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(initialsOf(review.riderName)),
                        ),
                        title: Row(
                          children: [
                            for (var i = 1; i <= 5; i++)
                              Icon(
                                i <= review.rating ? Icons.star : Icons.star_border,
                                size: 16,
                                color: Colors.amber.shade700,
                              ),
                          ],
                        ),
                        subtitle: Text(
                          review.comment.isEmpty ? 'Sin comentario' : review.comment,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _LeaveReview extends StatefulWidget {
  const _LeaveReview({required this.ride, required this.rides});

  final Ride ride;
  final RidesService rides;

  @override
  State<_LeaveReview> createState() => _LeaveReviewState();
}

class _LeaveReviewState extends State<_LeaveReview> {
  final _comment = TextEditingController();
  int _rating = 5;
  bool _saving = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final allowed = Guards.canReview(
      status: widget.ride.status,
      riderConfirmed: widget.ride.riderConfirmed,
      alreadyReviewed: false,
    );

    if (!allowed) {
      return const Padding(
        padding: EdgeInsets.all(28),
        child: Text(
          'La resena se abre cuando el viaje termina y tu lo confirmas.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Como te fue con ${widget.ride.driverName}?',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  onPressed: () => setState(() => _rating = i),
                  icon: Icon(
                    i <= _rating ? Icons.star : Icons.star_border,
                    size: 36,
                    color: Colors.amber.shade700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _comment,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Comentario (opcional)',
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    await widget.rides.leaveReview(
                      reviewId: '${widget.ride.id}_${auth.uid}',
                      rating: _rating,
                      comment: _comment.text.trim(),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Gracias por la resena.')),
                    );
                    Navigator.of(context).pop();
                  },
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enviar resena'),
          ),
        ],
      ),
    );
  }
}