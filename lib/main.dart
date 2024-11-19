import 'package:flutter/material.dart';
import 'dart:math' as math;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.greenAccent,
        body: Center(
          child: Dock(
            items: [
              Icons.person,
              Icons.message,
              Icons.call,
              Icons.camera,
              Icons.photo,
            ],
          ),
        ),
      ),
    );
  }
}

/// Extension for Clamping -------------------------------------------------------
extension OffsetX on Offset {
  Offset clampOffset(Offset min, Offset max) {
    return Offset(
      dx.clamp(min.dx, max.dx),
      dy.clamp(min.dy, max.dy),
    );
  }
}

/// Dock Widget Constructor ------------------------------------------------------
class Dock<T extends Object> extends StatefulWidget {
  const Dock({
    super.key,
    this.items = const [],
    this.minDockWidth = 10.0,
    this.itemBuilder,
  });

  final List<T> items;
  final double minDockWidth;
  final Widget Function(T)? itemBuilder;

  Widget defaultBuilder(T item) {
    if (item is IconData) {
      return Container(
        constraints: const BoxConstraints(minWidth: 48),
        height: 50,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 3),
            ),
          ],
          color: Colors.primaries[item.hashCode % Colors.primaries.length],
        ),
        child: Center(child: Icon(item as IconData, color: Colors.white)),
      );
    }
    return const SizedBox();
  }

  @override
  State<Dock<T>> createState() => _DockState<T>();
}

/// Stateful Dock Implementation -----------------------------------------------
class _DockState<T extends Object> extends State<Dock<T>>
    with TickerProviderStateMixin {
  // Key State Variables -------------------------------------------------------
  late List<T> _dockItems;
  final Map<T, Offset> _externalItems = {};
  final GlobalKey _dockKey = GlobalKey();

  T? _currentlyDraggingItem;
  T? _hoveredItem;
  bool _isDragging = false;
  int? _dragTargetIndex;

  // Constants for dock dimensions ---------------------------------------------
  static const double _itemWidth = 64.0;
  static const double _dockHeight = 70.0;
  static const double _dockPadding = 10;
  static const double _safeZone = 25;
  static const double _protectedZone = 100.0;
  static const double _proximityThreshold = 100.0;
  T? _itemBeingDraggedOut;
  List<T> get _currentDockItems {
    if (_currentlyDraggingItem != null &&
        _itemBeingDraggedOut == _currentlyDraggingItem &&
        !_isInDockArea(_lastKnownDragPosition)) {
      return _dockItems.where((item) => item != _itemBeingDraggedOut).toList();
    }
    return _dockItems;
  }

  Offset _lastKnownDragPosition = Offset.zero;
  bool _isDraggingOutside = false;

  @override
  void initState() {
    super.initState();
    _dockItems = widget.items.toList();
  }

  /// Dock Dimensions ----------------------------------------------------------
  // double get _calculatedDockWidth {
  //   final targetWidth = (_dockItems.length * _itemWidth) + (2 * _dockPadding);
  //   return math.max(targetWidth, widget.minDockWidth);
  // }

  /// Boundary Checks ----------------------------------------------------------
  bool _isInDockArea(Offset position) {
    final RenderBox? renderBox =
        _dockKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return false;

    final dockPosition = renderBox.localToGlobal(Offset.zero);
    final dockRect = Rect.fromLTWH(
      dockPosition.dx - _safeZone,
      dockPosition.dy - _safeZone,
      renderBox.size.width + (2 * _safeZone),
      renderBox.size.height + _safeZone,
    );

    return dockRect.contains(position);
  }

  bool _isInProtectedArea(Offset position) {
    final RenderBox? renderBox =
        _dockKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return false;

    final dockPosition = renderBox.localToGlobal(Offset.zero);
    final protectedRect = Rect.fromLTWH(
      dockPosition.dx - _protectedZone,
      dockPosition.dy - _protectedZone,
      renderBox.size.width + (2 * _protectedZone),
      renderBox.size.height + _protectedZone,
    );

    return protectedRect.contains(position);
  }

  bool _isNearDock(Offset position) {
    final RenderBox? renderBox =
        _dockKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return false;

    final dockPosition = renderBox.localToGlobal(Offset.zero);
    final dockRect = Rect.fromLTWH(
      dockPosition.dx - _proximityThreshold,
      dockPosition.dy - _proximityThreshold,
      renderBox.size.width + (2 * _proximityThreshold),
      renderBox.size.height + _proximityThreshold,
    );

    return dockRect.contains(position);
  }

  /// Valid Positioning ----------------------------------------------------------
  Offset _getValidPosition(Offset globalPosition) {
    final screenSize = MediaQuery.of(context).size;
    final maxDy = screenSize.height - _dockHeight - 40; // Leave space for dock

    return Offset(
      globalPosition.dx
          .clamp(_itemWidth / 2, screenSize.width - _itemWidth / 2),
      globalPosition.dy.clamp(_itemWidth / 2, maxDy),
    );
  }

  /// Drag and Drop Logic --------------------------------------------------------
  void _handleDragEnd(T item, DraggableDetails details) {
    if (_isDraggingOutside) {
      // If we were dragging outside, don't rearrange the dock
      setState(() {
        if (_dockItems.contains(item)) {
          _dockItems.remove(item);
        }
        _externalItems[item] = _getValidPosition(details.offset);
      });
    } else if (_isInDockArea(details.offset) || _isNearDock(details.offset)) {
      setState(() {
        _externalItems.remove(item);
        if (!_dockItems.contains(item)) {
          _dockItems.add(item);
        }
      });
    } else {
      setState(() {
        if (_dockItems.contains(item)) {
          _dockItems.remove(item);
        }
        _externalItems[item] = _getValidPosition(details.offset);
      });
    }
    setState(() {
      _itemBeingDraggedOut = null;
      _currentlyDraggingItem = null;
      _isDragging = false;
      _dragTargetIndex = null;
      _hoveredItem = null;
      _lastKnownDragPosition = Offset.zero;
      _isDraggingOutside = false;
    });
  }

  /// External Items logic -----------------------------------------------------
  Widget _buildExternalItem(T item, Offset position) {
    return Positioned(
      left: position.dx - (_itemWidth / 2),
      top: position.dy - (_itemWidth / 2),
      width: _itemWidth,
      height: _itemWidth,
      child: Material(
        color: Colors.transparent,
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: Draggable<T>(
            data: item,
            feedback: Material(
              color: Colors.transparent,
              child: Transform.scale(
                scale: 1.4,
                child: widget.itemBuilder?.call(item) ??
                    widget.defaultBuilder(item),
              ),
            ),
            childWhenDragging: const SizedBox(),
            onDragStarted: () {
              setState(() {
                _isDragging = true;
                _currentlyDraggingItem = item;
              });
            },
            onDragEnd: (details) => _handleDragEnd(item, details),
            child:
                widget.itemBuilder?.call(item) ?? widget.defaultBuilder(item),
          ),
        ),
      ),
    );
  }

  /// Reordering Items -----------------------------------------------------------
  void _handleDragUpdate(T item, DragUpdateDetails details, int index) {
    _lastKnownDragPosition = details.globalPosition;

    final RenderBox? renderBox =
        _dockKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    bool isOutside = !_isInDockArea(details.globalPosition) &&
        !_isInProtectedArea(details.globalPosition);

    setState(() {
      _isDraggingOutside = isOutside;
      if (isOutside) {
        _itemBeingDraggedOut = item;
        // Don't allow reordering when dragging outside
        _dragTargetIndex = null;
        return;
      } else {
        _itemBeingDraggedOut = null;
      }
    });

    if (_isInDockArea(details.globalPosition)) {
      final localPosition = renderBox.globalToLocal(details.globalPosition);
      final currentItems = _currentDockItems;
      int newIndex = ((localPosition.dx - _dockPadding) / _itemWidth)
          .floor()
          .clamp(0, currentItems.length - 1);

      if (newIndex != _dragTargetIndex &&
          newIndex >= 0 &&
          newIndex < currentItems.length) {
        setState(() {
          if (_dockItems.contains(item) && !_isDraggingOutside) {
            final itemToMove = _dockItems.removeAt(index);
            _dockItems.insert(newIndex, itemToMove);
          }
          _dragTargetIndex = newIndex;
        });
      }
    }
  }

  /// Widget Rendering ---------------------------------------------------------
  Widget _buildDockItem(T item, int index) {
    final isBeingDragged = _currentlyDraggingItem == item;
    final isHovered = _hoveredItem == item;
    final shouldScale = isBeingDragged || isHovered;

    final isVisuallyHidden = _isDraggingOutside && item == _itemBeingDraggedOut;

    final currentItems = _currentDockItems;
    final visualIndex = currentItems.indexOf(item);

    if (visualIndex == -1 && !isBeingDragged) return const SizedBox();

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      left: _dockPadding + (visualIndex * _itemWidth),
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        onEnter: (_) => setState(() {
          if (!_isDragging) _hoveredItem = item;
        }),
        onExit: (_) => setState(() {
          if (!_isDragging && _hoveredItem == item) _hoveredItem = null;
        }),
        child: Draggable<T>(
          data: item,
          feedback: Material(
            color: Colors.transparent,
            child: Transform.scale(
              scale: 1.4,
              child:
                  widget.itemBuilder?.call(item) ?? widget.defaultBuilder(item),
            ),
          ),
          childWhenDragging: const SizedBox(),
          onDragStarted: () {
            setState(() {
              _currentlyDraggingItem = item;
              _isDragging = true;
              _dragTargetIndex = index;
              _hoveredItem = null;
            });
          },
          onDragUpdate: (details) => _handleDragUpdate(item, details, index),
          onDragEnd: (details) => _handleDragEnd(item, details),
          child: AnimatedScale(
            scale: shouldScale ? 1.4 : 1.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: isVisuallyHidden ? 0.0 : 1.0,
              child:
                  widget.itemBuilder?.call(item) ?? widget.defaultBuilder(item),
            ),
          ),
        ),
      ),
    );
  }

  /// Complete UI --------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final currentItems = _currentDockItems;
    final currentDockWidth =
        (currentItems.length * _itemWidth) + (2 * _dockPadding);

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // External items
          ..._externalItems.entries.map((entry) {
            return _buildExternalItem(entry.key, entry.value);
          }).toList(),

          // Dock
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: math.max(currentDockWidth, widget.minDockWidth),
                height: _dockHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.black12,
                ),
                child: Stack(
                  key: _dockKey,
                  clipBehavior: Clip.none,
                  children: _dockItems
                      .map((item) =>
                          _buildDockItem(item, _dockItems.indexOf(item)))
                      .toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
