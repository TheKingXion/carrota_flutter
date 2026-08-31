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

  late final PageController _pageController;
  final Map<int, VideoPlayerController> _videos = {};
  final Set<int> _readyVideos = {};
  final Set<int> _loadingVideos = {};
  var _muted = true;
  var _feedIndex = 0;
  String? _addedProduct;
  Timer? _addedTimer;

  AppStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    unawaited(_prepareVideosAround(0));
  }

  Future<void> _prepareVideosAround(int index) async {
    final indexes = <int>{
      if (index > 0) index - 1,
      index,
      if (index < _videoAssets.length - 1) index + 1,
    };
    await Future.wait(indexes.map(_initializeVideo));
    if (mounted) _disposeDistantVideos(_feedIndex);
  }

  Future<void> _initializeVideo(int index) async {
    if (index < 0 || index >= _videoAssets.length) return;
    if (_videos.containsKey(index) || !_loadingVideos.add(index)) return;
    final controller = VideoPlayerController.asset(
      _videoAssets[index % _videoAssets.length],
    );
    _videos[index] = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(_muted ? 0 : 1);
      if (!mounted || _videos[index] != controller) {
        await controller.dispose();
        return;
      }
      _readyVideos.add(index);
      if (index == _feedIndex) {
        await controller.play();
      } else {
        await controller.pause();
      }
      if (mounted) setState(() {});
    } catch (_) {
      if (_videos[index] == controller) {
        _videos.remove(index);
        _readyVideos.remove(index);
      }
      await controller.dispose();
    } finally {
      _loadingVideos.remove(index);
    }
  }

  void _disposeDistantVideos(int center) {
    final distant = _videos.keys
        .where(
          (index) =>
              (index - center).abs() > 1 && !_loadingVideos.contains(index),
        )
        .toList();
    for (final index in distant) {
      final controller = _videos.remove(index);
      _readyVideos.remove(index);
      if (controller != null) unawaited(controller.dispose());
    }
  }

  void _onPageChanged(int index) {
    setState(() => _feedIndex = index);
    for (final entry in _videos.entries) {
      if (!_readyVideos.contains(entry.key)) continue;
      if (entry.key == index) {
        unawaited(entry.value.play());
      } else {
        unawaited(entry.value.pause());
      }
    }
    unawaited(_prepareVideosAround(index));
  }

  @override
  void dispose() {
    _addedTimer?.cancel();
    _pageController.dispose();
    for (final controller in _videos.values) {
      unawaited(controller.dispose());
    }
    _videos.clear();
    super.dispose();
  }

  Future<void> _toggleMute() async {
    _muted = !_muted;
    await Future.wait(
      _videos.entries
          .where((entry) => _readyVideos.contains(entry.key))
          .map((entry) => entry.value.setVolume(_muted ? 0 : 1)),
    );
    if (mounted) setState(() {});
  }

  Future<void> _togglePlayback() async {
    final video = _videos[_feedIndex];
    if (!_readyVideos.contains(_feedIndex) || video == null) return;
    video.value.isPlaying ? await video.pause() : await video.play();
    if (mounted) setState(() {});
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

  Future<void> _showComments(
    BuildContext context,
    Product product,
  ) async {
    final controller = TextEditingController();
    final comments = store.feedCommentsFor(product.id);
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
                "Comentarios de ${product.name} (${comments.length})",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ...comments.reversed.take(5).map(
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
                      store.addFeedComment(product.id, controller.text);
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

    return Material(
      color: const Color(0xFF071711),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            PageView.builder(
              key: const ValueKey("vertical-product-feed"),
              controller: _pageController,
              scrollDirection: Axis.vertical,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              itemCount: feedProducts.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) => _buildFeedPage(
                context,
                product: feedProducts[index],
                index: index,
                total: feedProducts.length,
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
    );
  }

  Widget _buildFeedPage(
    BuildContext context, {
    required Product product,
    required int index,
    required int total,
  }) {
    final comments = store.feedCommentsFor(product.id);
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _togglePlayback,
            child: _ImmersiveBackdrop(
              controller: _videos[index],
              ready: _readyVideos.contains(index),
            ),
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
                product: product,
                lowStock: product.stock <= product.averageDaily,
                onDetails: () => widget.onOpenProduct(product.id),
                onAdd: () => _addToCart(product),
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
                  _QuickAction(label: "Cierre", onTap: widget.onOpenClosing),
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
                icon: store.isFeedLiked(product.id)
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: "${store.feedLikeCountFor(product.id)}",
                active: store.isFeedLiked(product.id),
                onTap: () => store.toggleFeedLike(product.id),
              ),
              const SizedBox(height: 14),
              _ImmersiveAction(
                icon: Icons.mode_comment_rounded,
                label: "${comments.length}",
                onTap: () => _showComments(context, product),
              ),
              const SizedBox(height: 14),
              _ImmersiveAction(
                icon: store.isFeedSaved(product.id)
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                label: "Guardar",
                active: store.isFeedSaved(product.id),
                onTap: () => store.toggleFeedSaved(product.id),
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
                onTap: () => _share(context, product),
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
                "${index + 1} / $total",
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
          left: 16,
          bottom: 18,
          child: _SwipeHint(index: index, total: total),
        ),
      ],
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

class _SwipeHint extends StatelessWidget {
  const _SwipeHint({required this.index, required this.total});

  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final atStart = index == 0;
    final atEnd = index == total - 1;
    final label = atStart
        ? "Desliza hacia arriba"
        : atEnd
            ? "Desliza hacia abajo"
            : "Desliza arriba o abajo";
    final icon = atStart
        ? Icons.keyboard_double_arrow_up_rounded
        : atEnd
            ? Icons.keyboard_double_arrow_down_rounded
            : Icons.unfold_more_rounded;

    return IgnorePointer(
      child: Container(
        key: const ValueKey("swipe-hint"),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xA6192822),
          border: Border.all(color: const Color(0x42FFFFFF)),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 17),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
