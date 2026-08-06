enum PaymentMethod { efectivo, tarjeta, transferencia, combinado }

enum AiProviderChoice { automatic, openai, deepseek }

class BusinessProfile {
  const BusinessProfile({
    required this.ownerName,
    required this.businessName,
    required this.businessType,
    required this.currency,
  });

  final String ownerName;
  final String businessName;
  final String businessType;
  final String currency;

  BusinessProfile copyWith({
    String? ownerName,
    String? businessName,
    String? businessType,
    String? currency,
  }) {
    return BusinessProfile(
      ownerName: ownerName ?? this.ownerName,
      businessName: businessName ?? this.businessName,
      businessType: businessType ?? this.businessType,
      currency: currency ?? this.currency,
    );
  }
}

class Product {
  Product({
    required this.id,
    required this.name,
    required this.unit,
    required this.price,
    required this.stock,
    required this.emoji,
    required this.supplier,
    required this.averageDaily,
  });

  final String id;
  final String name;
  final String unit;
  double price;
  double stock;
  final String emoji;
  final String supplier;
  final double averageDaily;
}

class SaleLine {
  const SaleLine({required this.productId, required this.quantity});

  final String productId;
  final double quantity;
}

class Sale {
  Sale({
    required this.id,
    required this.lines,
    required this.total,
    required this.time,
    this.payment,
    this.authorization,
  });

  final String id;
  final List<SaleLine> lines;
  final double total;
  final String time;
  PaymentMethod? payment;
  String? authorization;
}

enum MessageType { user, text, sale, impact, insight, receipt }

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.type,
    this.text,
    this.sale,
    this.items = const [],
    this.productId,
    this.aiProvider,
    this.aiModel,
    this.confirmed = false,
  });

  final String id;
  final MessageType type;
  final String? text;
  final Sale? sale;
  final List<String> items;
  final String? productId;
  final String? aiProvider;
  final String? aiModel;
  bool confirmed;
}

class MemoryEvent {
  const MemoryEvent({
    required this.id,
    required this.group,
    required this.when,
    required this.title,
    required this.detail,
    required this.kind,
  });

  final String id;
  final String group;
  final String when;
  final String title;
  final String detail;
  final String kind;
}

class TimelineEvent {
  const TimelineEvent({
    required this.id,
    required this.time,
    required this.title,
    this.detail = "",
    this.tag = "",
  });

  final String id;
  final String time;
  final String title;
  final String detail;
  final String tag;
}

class ShoppingEntry {
  ShoppingEntry({
    required this.productId,
    required this.quantity,
    required this.reason,
    this.selected = true,
  });

  final String productId;
  double quantity;
  final String reason;
  bool selected;
}
