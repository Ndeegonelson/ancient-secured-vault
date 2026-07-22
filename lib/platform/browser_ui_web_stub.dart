final platformViewRegistry = _PlatformViewRegistry();

class _PlatformViewRegistry {
  void registerViewFactory(
    String viewType,
    Object Function(int viewId) factory,
  ) {}
}
