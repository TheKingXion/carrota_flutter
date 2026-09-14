import "dart:async";

import "package:flutter/material.dart";
import "package:share_plus/share_plus.dart";
import "package:video_player/video_player.dart";

import "app_store.dart";
import "feed_video_controller.dart";
import "models.dart";
import "sheets.dart";
import "theme.dart";
import "widgets.dart";

final feedRouteObserver = RouteObserver<ModalRoute<dynamic>>();

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.store,
    this.active = true,
    this.videoControllerFactory,
    required this.onOpenProduct,
    required this.onOpenDelivery,
    required this.onOpenClosing,
  });

  final AppStore store;
  final bool active;
  final VideoPlayerController Function(String)? videoControllerFactory;
  final ValueChanged<String> onOpenProduct;
  final VoidCallback onOpenDelivery;
  final VoidCallback onOpenClosing;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, RouteAware {
  static const _videoAssets = [
    "assets/videos/fresh_fruit.mp4",
    "assets/videos/lettuce.mp4",
    "assets/videos/apples.mp4",
    "assets/videos/lemons.mp4",
    "assets/videos/citrus.mp4",
  ];

  late final PageController _pageController;
  late final FeedVideoController _feed;
  bool _foreground = true;
  bool _routeVisible = true;
  ModalRoute<dynamic>? _route;
  String? _addedProduct;
  Timer? _addedTimer;

  AppStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _feed =
        FeedVideoController(_videoAssets, create: widget.videoControllerFactory)
          ..addListener(_refresh);
    store.addListener(_refresh);
    _updateActivity();
    _feed.select(0);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route) {
      feedRouteObserver.unsubscribe(this);
      _route = route;
      if (route != null) feedRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != store) {
      oldWidget.store.removeListener(_refresh);
      store.addListener(_refresh);
    }
    _updateActivity();
  }

  void _updateActivity() =>
      _feed.setActive(widget.active && _foreground && _routeVisible);

  @override
  void didPushNext() {
    _routeVisible = false;
    _updateActivity();
  }

  @override
  void didPopNext() {
    _routeVisible = true;
    _updateActivity();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _updateActivity();
  }

  @override
  void dispose() {
    feedRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    store.removeListener(_refresh);
    _addedTimer?.cancel();
    _pageController.dispose();
    _feed.removeListener(_refresh);
    _feed.dispose();
    super.dispose();
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

  Future<void> _showComments(BuildContext context, Product product) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        constraints: const BoxConstraints(maxWidth: 430),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (_) => _FeedCommentsSheet(store: store, product: product),
      );

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
    final feedProducts = store.products.take(_videoAssets.length).toList();

    return Material(
      color: const Color(0xFF071711),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            if (feedProducts.isEmpty)
              const Center(
                  child: Text("Aún no hay productos",
                      style: TextStyle(color: Colors.white)))
            else
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.depth != 0) return false;
                  if (notification is ScrollStartNotification) {
                    _feed.setScrolling(true);
                  }
                  if (notification is ScrollEndNotification) {
                    _feed.setScrolling(false);
                  }
                  return false;
                },
                child: PageView.builder(
                  key: const ValueKey("vertical-product-feed"),
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  physics: const ClampingScrollPhysics(),
                  itemCount: feedProducts.length,
                  onPageChanged: _feed.select,
                  itemBuilder: (context, index) => RepaintBoundary(
                    key: ValueKey("feed-page-$index"),
                    child: _buildFeedPage(
                      context,
                      product: feedProducts[index],
                      index: index,
                      total: feedProducts.length,
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
    );
  }

  Widget _buildFeedPage(
    BuildContext context, {
    required Product product,
    required int index,
    required int total,
  }) {
    final comments = store.feedCommentsFor(product.id);
    return LayoutBuilder(
        builder: (context, constraints) => Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _feed.togglePlayback,
                    child: _ImmersiveBackdrop(
                      controller: _feed.player(index),
                      ready: _feed.player(index) != null,
                      failed: _feed.failed(index),
                      paused: _feed.paused(index),
                      onRetry: () => _feed.retry(index),
                      poster: _videoAssets[index]
                          .replaceFirst("videos/", "posters/")
                          .replaceFirst(".mp4", ".jpg"),
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 74,
                  top: 16,
                  child: Row(children: [
                    const LumoMark(size: 35),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(store.businessName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800)),
                        Text("${store.ownerName} · ${index + 1} de $total",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11)),
                      ],
                    )),
                  ]),
                ),
                Positioned(
                  left: 18,
                  right: 84,
                  bottom: 64,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (constraints.maxHeight >= 640) ...[
                        const Text("Tu negocio,\nen movimiento.",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                height: 1.05,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                      ],
                      _FocusCard(
                        product: product,
                        lowStock: product.stock <= product.averageDaily,
                        onDetails: () => widget.onOpenProduct(product.id),
                        onAdd:
                            product.stock - store.cartQuantityFor(product.id) >=
                                    1
                                ? () => _addToCart(product)
                                : null,
                      ),
                      const SizedBox(height: 10),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        _QuickAction(
                            label: "Alertas",
                            onTap: () => _showAlerts(context)),
                        _QuickAction(
                            label: "Recibir", onTap: widget.onOpenDelivery),
                        _QuickAction(
                            label: "Cierre", onTap: widget.onOpenClosing),
                      ]),
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
                    tooltip: _feed.muted ? "Activar sonido" : "Silenciar",
                    onPressed: _feed.toggleMute,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0x990B1510),
                      foregroundColor: Colors.white,
                    ),
                    icon: Icon(
                      _feed.muted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  bottom: 18,
                  child: _SwipeHint(index: index, total: total),
                ),
              ],
            ));
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard(
      {required this.product,
      required this.lowStock,
      required this.onDetails,
      required this.onAdd});
  final Product product;
  final bool lowStock;
  final VoidCallback onDetails;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            InkWell(
              onTap: onDetails,
              borderRadius: BorderRadius.circular(12),
              child: Row(children: [
                Text(product.emoji, style: const TextStyle(fontSize: 30)),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text("${AppStore.money(product.price)} / ${product.unit}",
                          style: const TextStyle(
                              color: primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 12)),
                      Text(
                          lowStock
                              ? "Quedan ${AppStore.number(product.stock)} ${product.unit}"
                              : "Ver detalles",
                          style:
                              const TextStyle(color: mutedInk, fontSize: 11)),
                    ])),
              ]),
            ),
            const SizedBox(height: 10),
            SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onAdd,
                  child: Text(product.stock <= 0 ? "Agotado" : "Agregar"),
                )),
          ]),
        ),
      );
}

class _ImmersiveBackdrop extends StatelessWidget {
  const _ImmersiveBackdrop({
    required this.controller,
    required this.ready,
    required this.failed,
    required this.paused,
    required this.onRetry,
    required this.poster,
  });

  final VideoPlayerController? controller;
  final String poster;
  final bool ready;
  final bool failed;
  final bool paused;
  final VoidCallback onRetry;

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
          Positioned.fill(
              child: Image.asset(poster,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  gaplessPlayback: true)),
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
          if (!ready)
            Positioned(
              top: 72,
              left: 18,
              right: 84,
              child: DecoratedBox(
                decoration: BoxDecoration(
                    color: const Color(0xCC071711),
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                        failed
                            ? "No se pudo cargar el video"
                            : "Preparando video…",
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12)),
                    if (failed)
                      TextButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        label: const Text("Reintentar",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                  ]),
                ),
              ),
            ),
          if (ready && paused)
            const Center(
                child: Icon(Icons.play_circle_fill_rounded,
                    size: 68, color: Colors.white70)),
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
            Flexible(
                child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            )),
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

class _FeedCommentsSheet extends StatefulWidget {
  const _FeedCommentsSheet({required this.store, required this.product});
  final AppStore store;
  final Product product;
  @override
  State<_FeedCommentsSheet> createState() => _FeedCommentsSheetState();
}

class _FeedCommentsSheetState extends State<_FeedCommentsSheet> {
  final _text = TextEditingController();
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    if (_text.text.trim().isEmpty) return;
    widget.store.addFeedComment(widget.product.id, _text.text);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              18, 16, 18, 24 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Comentarios de ${widget.product.name}",
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (widget.store.feedCommentsFor(widget.product.id).isEmpty)
                const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text("Sé el primero en comentar.")),
              ...widget.store
                  .feedCommentsFor(widget.product.id)
                  .reversed
                  .take(5)
                  .map((comment) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading:
                          const CircleAvatar(child: Icon(Icons.person_rounded)),
                      title: const Text("Cliente demo"),
                      subtitle: Text(comment))),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: _text,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _submit(),
                        decoration: const InputDecoration(
                            hintText: "Añadir comentario…"))),
                const SizedBox(width: 8),
                IconButton.filled(
                    tooltip: "Publicar",
                    onPressed: _submit,
                    icon: const Icon(Icons.arrow_upward_rounded)),
              ]),
            ],
          ),
        ),
      );
}
