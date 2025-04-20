import 'package:flutter/material.dart';

class TagboxLogo extends StatelessWidget {
  final double size;

  const TagboxLogo({Key? key, this.size = 120.0}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        borderRadius: BorderRadius.circular(size / 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Tag shape
          Icon(
            Icons.local_offer_rounded,
            size: size * 0.6,
            color: Colors.blue.shade700,
          ),
          // Box outline
          Container(
            width: size * 0.8,
            height: size * 0.8,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.blue.shade900,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(size / 8),
            ),
          ),
          // Text
          Positioned(
            bottom: size * 0.15,
            child: Text(
              'TagBox',
              style: TextStyle(
                color: Colors.blue.shade900,
                fontSize: size * 0.2,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 