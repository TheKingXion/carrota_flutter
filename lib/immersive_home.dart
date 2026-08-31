import "dart:async";

import "package:flutter/material.dart";
import "package:share_plus/share_plus.dart";
import "package:video_player/video_player.dart";

import "app_store.dart";
import "models.dart";
import "sheets.dart";
import "theme.dart";
import "widgets.dart";

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.store,
    required this.onOpenProduct,
    required this.onOpenDelivery,
    required this.onOpenClosing,
  });

  final AppStore store;
  final ValueChanged<String> onOpenProduct;
  final VoidCallback onOpenDelivery;
  final VoidCallback onOpenClosing;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _videoAssets = [
    "assets/videos/fresh_fruit.mp4",
    "assets/videos/lettuce.mp4",
    "assets/videos/apples.mp4",
    "assets/videos/lemons.mp4",
    "assets/videos/citrus.mp4",
  ];

  VideoPlayerController? _video;
  var _videoReady = false;
  var _muted = true;
  var _feedIndex = 0;
  var _videoGeneration = 0;
  String? _addedProduct;
  Timer? _addedTimer;

  AppStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    _loadVideo(0);
  }

  Future<void> _loadVideo(int index) async {
    final generation = ++_videoGeneration;
    final previous = _video;
    _video = null;
    _videoReady = false;
    await previous?.dispose();
    final controller = VideoPlayerController.asset(
      _videoAssets[index % _videoAssets.length],
    );
    _video = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(_muted ? 0 : 1);
      await controller.play();
      if (!mounted || generation != _videoGeneration) {
        await controller.dispose();
        return;
      }
      if (mounted) setState(() => _videoReady = true);
    } catch (_) {
      if (mounted && generation == _videoGeneration) {
        setState(() => _videoReady = false);
      }
    }
  }

  @override
  void dispose() {
    _videoGeneration++;
    _addedTimer?.cancel();
    _video?.dispose();
    super.dispose();
  }

  Future<void> _toggleMute() async {
    final video = _video;
    if (video == null) return;
    _muted = !_muted;
    await video.setVolume(_muted ? 0 : 1);
    if (mounted) setState(() {});
  }

  Future<void> _togglePlayback() async {
    final video = _video;
    if (!_videoReady || video == null) return;
    video.value.isPlaying ? await video.pause() : await video.play();
    if (mounted) setState(() {});
  }

  void _moveFeed(int direction) {
    final next = (_feedIndex + direction).clamp(0, 4);
    if (next == _feedIndex) return;
    setState(() => _feedIndex = next);
    unawaited(_loadVideo(next));
  }

  void _addToCart(Product product) {
    final added = store.addToCart(product.id);
    if (!added) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No hay más stock disponible.")),
      );
      return;
    }
    _addedTimer?.cancel();
    setState(() => _addedProduct = product.name);
    _addedTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _addedProduct = null);
    });
  }

  Future<void> _showComments(BuildContext context) async {
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 430),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: hairline,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Comentarios (${store.feedComments.length})",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ...store.feedComments.reversed.take(5).map(
                    (comment) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: primarySoft,
                        child: Icon(Icons.person_rounded, color: primary),
                      ),
                      title: const Text("Cliente demo"),
                      subtitle: Text(comment),
                    ),
                  ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: "Añadir comentario…",
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: "Publicar",
                    onPressed: () {
                      if (controller.text.trim().isEmpty) return;
                      store.addFeedComment(controller.text);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _share(BuildContext context, Product product) async {
    final box = context.findRenderObject() as RenderBox?;
    try {
      await SharePlus.instance.share(
        ShareParams(
          title: product.name,
          subject: "Mira este producto en ${store.businessName}",
          text:
              "${product.emoji} ${product.name} por ${AppStore.money(product.price)} cada ${product.unit}. Disponible en ${store.businessName}.",
          sharePositionOrigin:
              box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("El menú para compartir no está disponible.")),
      );
    }
  }

  void _showAlerts(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Atención de inventario"),
        content: store.lowStockProducts.isEmpty
            ? const Text("No hay productos con stock bajo.")
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: store.lowStockProducts
                    .map(
                      (product) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Text(
                          product.emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                        title: Text(product.name),
                        subtitle: Text(
                          "Quedan ${AppStore.number(product.stock)} ${product.unit}",
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          widget.onOpenProduct(product.id);
                        },
                      ),
                    )
                    .toList(),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedProducts = store.products.take(5).toList();
    final focus = feedProducts[_feedIndex % feedProducts.length];

    return Material(
      color: const Color(0xFF071711),
      child: SafeArea(
        bottom: false,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _togglePlayback,
          onVerticalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity < -180) _moveFeed(1);
            if (velocity > 180) _moveFeed(-1);
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: _ImmersiveBackdrop(
                  controller: _video,
                  ready: _videoReady,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 72, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const LumoMark(size: 35),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                store.businessName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                "${store.ownerName} · datos locales",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xBFFFFFFF),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 104),
                    Text(
                      "Tu negocio,\nen movimiento.",
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: Colors.white,
                            fontFamily: "serif",
                            fontSize: 43,
                            height: .98,
                            letterSpacing: -1.5,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "${AppStore.money(store.salesToday)} hoy · "
                      "${store.operationsToday} operaciones",
                      style: const TextStyle(
                        color: Color(0xDFFFFFFF),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _FocusCard(
                      product: focus,
                      lowStock: store.lowStockProducts.isNotEmpty,
                      onDetails: () => widget.onOpenProduct(focus.id),
                      onAdd: () => _addToCart(focus),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _QuickAction(
                          label: "Alertas",
                          onTap: () => _showAlerts(context),
                        ),
                        _QuickAction(
                          label: "Recibir",
                          onTap: widget.onOpenDelivery,
                        ),
                        _QuickAction(
                            label: "Cierre", onTap: widget.onOpenClosing),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 12,
                bottom: 28,
                child: Column(
                  children: [
                    _ImmersiveAction(
                      icon: store.feedLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      label: "${store.feedLikeCount}",
                      active: store.feedLiked,
                      onTap: store.toggleFeedLike,
                    ),
                    const SizedBox(height: 14),
                    _ImmersiveAction(
                      icon: Icons.mode_comment_rounded,
                      label: "${store.feedComments.length}",
                      onTap: () => _showComments(context),
                    ),
                    const SizedBox(height: 14),
                    _ImmersiveAction(
                      icon: store.feedSaved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      label: "Guardar",
                      active: store.feedSaved,
                      onTap: store.toggleFeedSaved,
                    ),
                    const SizedBox(height: 14),
                    _CartAction(
                      count: store.cartItemCount,
                      onTap: () => showCartSheet(context, store),
                    ),
                    const SizedBox(height: 14),
                    _ImmersiveAction(
                      icon: Icons.arrow_outward_rounded,
                      label: "Compartir",
                      onTap: () => _share(context, focus),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: IconButton.filled(
                  tooltip: _muted ? "Activar sonido" : "Silenciar",
                  onPressed: _toggleMute,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0x990B1510),
                    foregroundColor: Colors.white,
                  ),
                  icon: Icon(
                    _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 18,
                child: IgnorePointer(
                  child: Center(
                    child: Text(
                      "${_feedIndex + 1} / ${feedProducts.length}",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                top: 64,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _addedProduct == null
                      ? const SizedBox.shrink()
                      : Material(
                          key: ValueKey(_addedProduct),
                          color: Colors.white,
                          elevation: 10,
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => showCartSheet(context, store),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 11,
                              ),
                              child: Row(
                                children: [
                                  const CircleAvatar(
                                    radius: 17,
                                    backgroundColor: primarySoft,
                                    child: Icon(
                                      Icons.check_rounded,
                                      color: primary,
                                      size: 19,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      "$_addedProduct se agregó al carrito",
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const Text(
                                    "Ver",
                                    style: TextStyle(
                                      color: primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({
    required this.product,
    required this.lowStock,
    required this.onDetails,
    required this.onAdd,
  });

  final Product product;
  final bool lowStock;
  final VoidCallback onDetails;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x44000000),
              blurRadius: 28,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: primarySoft,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(product.emoji, style: const TextStyle(fontSize: 28)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onDetails,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        "${AppStore.money(product.price)} / ${product.unit}",
                        style: const TextStyle(
                          color: primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        lowStock
                            ? "Quedan ${AppStore.number(product.stock)} ${product.unit}"
                            : "Toca para ver detalles",
                        style: const TextStyle(color: mutedInk, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            FilledButton(
              onPressed: onAdd,
              style: FilledButton.styleFrom(
                minimumSize: const Size(74, 38),
                padding: const EdgeInsets.symmetric(horizontal: 13),
              ),
              child: const Text("Agregar"),
            ),
          ],
        ),
      );
}

class _ImmersiveBackdrop extends StatelessWidget {
  const _ImmersiveBackdrop({
    required this.controller,
    required this.ready,
  });

  final VideoPlayerController? controller;
  final bool ready;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF163F2D),
                  Color(0xFF0C251B),
                  Color(0xFF050D09),
                ],
              ),
            ),
            child: SizedBox.expand(),
          ),
          if (ready && controller != null)
            Positioned.fill(
              child: ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller!.value.size.width,
                    height: controller!.value.size.height,
                    child: VideoPlayer(controller!),
                  ),
                ),
              ),
            ),
          if (!ready)
            Positioned(
              right: -80,
              top: 20,
              child: Container(
                width: 260,
                height: 260,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x6656C889), Color(0x0056C889)],
                  ),
                ),
              ),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x33000000), Color(0xD9000000)],
                stops: [.25, 1],
              ),
            ),
            child: SizedBox.expand(),
          ),
        ],
      );
}

class _ImmersiveAction extends StatelessWidget {
  const _ImmersiveAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          IconButton.filled(
            onPressed: onTap,
            style: IconButton.styleFrom(
              backgroundColor: active ? primary : const Color(0xB3192822),
              foregroundColor: Colors.white,
              minimumSize: const Size(48, 48),
            ),
            icon: Icon(icon, size: 22),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
}

class _CartAction extends StatelessWidget {
  const _CartAction({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Badge(
            isLabelVisible: count > 0,
            label: Text("$count"),
            backgroundColor: const Color(0xFFE7484B),
            child: IconButton.filled(
              tooltip: "Abrir carrito",
              onPressed: onTap,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xB3192822),
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 48),
              ),
              icon: const Icon(Icons.shopping_bag_rounded, size: 22),
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            "Carrito",
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
        onPressed: onTap,
        side: const BorderSide(color: Color(0x66FFFFFF)),
        backgroundColor: const Color(0x331F352B),
        labelStyle: const TextStyle(color: Colors.white, fontSize: 11),
        label: Text(label),
      );
}
