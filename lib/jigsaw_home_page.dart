import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:http/http.dart' as http;

class JigsawHomePage extends StatefulWidget {
  @override
  _JigsawHomePageState createState() => _JigsawHomePageState();
}

class _JigsawHomePageState extends State<JigsawHomePage>
    with SingleTickerProviderStateMixin {
  ui.Image canvasImage;
  bool _loaded = false;
  List<JigsawPiece> pieceOnBoard = [];
  List<JigsawPiece> pieceOnPool = [];

  JigsawPiece _currentPiece;
  Animation<Offset> _offsetAnimation;

  final _boardWidgetKey = GlobalKey();

  AnimationController _animController;

  @override
  void initState() {
    _animController = AnimationController(vsync: this);
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) _prepareGame();
  }

  void _prepareGame() async {
    pieceOnPool.clear();
    pieceOnBoard.clear();

    setState(() {
      _loaded = false;
    });
    final screenPixelScale = MediaQuery.of(context).devicePixelRatio;
    final imageSize = (300 * screenPixelScale).toInt();
    print('image size: $imageSize');
    final response =
        await http.get('https://picsum.photos/$imageSize/$imageSize');
    final imageData = response.bodyBytes;
    print('Loaded ${imageData.length} bytes');

    final image = MemoryImage(imageData, scale: screenPixelScale);
    canvasImage = await _getImage(image);
    pieceOnPool = _createJigsawPiece();
    pieceOnPool.shuffle();

    setState(() {
      _loaded = true;
      print('Loading done');
    });
  }

  Future<ui.Image> _getImage(ImageProvider image) async {
    final completer = Completer<ImageInfo>();
    image
        .resolve(ImageConfiguration())
        .addListener(ImageStreamListener((info, _) {
      completer.complete(info);
    }));
    ImageInfo imageInfo = await completer.future;
    return imageInfo.image;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.grey.shade700,
          appBar: AppBar(
            title: Text('Jigsaw'),
            actions: [
              IconButton(
                icon: Icon(Icons.refresh),
                onPressed: () {
                  _prepareGame();
                },
              )
            ],
          ),
          body: _loaded
              ? Column(
                  children: [
                    Container(
                      height: 400,
                      alignment: Alignment.center,
                      child: _buildBoard(),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.all(32),
                        scrollDirection: Axis.horizontal,
                        physics: BouncingScrollPhysics(),
                        itemCount: pieceOnPool.length,
                        itemBuilder: (context, index) {
                          final piece = pieceOnPool[index];
                          return Center(
                            child: Draggable(
                              child: piece,
                              feedback: piece,
                              childWhenDragging: Opacity(
                                opacity: 0.24,
                                child: piece,
                              ),
                              onDragEnd: (details) {
                                _onPiecePlaced(piece, details.offset);
                              },
                            ),
                          );
                        },
                        separatorBuilder: (context, index) =>
                            SizedBox(width: 32),
                      ),
                    ),
                  ],
                )
              : Center(child: CircularProgressIndicator()),
        ),
        if (_currentPiece != null)
          AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              final offset = _offsetAnimation.value;
              return Positioned(
                left: offset.dx,
                top: offset.dy,
                child: child,
              );
            },
            child: _currentPiece,
          )
      ],
    );
  }

  Widget _buildBoard() {
    return Container(
      key: _boardWidgetKey,
      width: 300,
      height: 300,
      color: Colors.grey.shade800,
      child: Stack(
        children: [
          for (var piece in pieceOnBoard)
            Positioned(
              left: piece.boundary.left,
              top: piece.boundary.top,
              child: piece,
            ),
        ],
      ),
    );
  }

  List<JigsawPiece> _createJigsawPiece() {
    return [
      for (int i = 0; i < 4; i++)
        for (int j = 0; j < 4; j++)
          JigsawPiece(
            key: UniqueKey(),
            image: canvasImage,
            imageSize: Size(300, 300),
            points: [
              Offset((i / 4) * 300, (j / 4) * 300),
              Offset(((i + 1) / 4) * 300, (j / 4) * 300),
              Offset(((i + 1) / 4) * 300, ((j + 1) / 4) * 300),
              Offset((i / 4) * 300, ((j + 1) / 4) * 300),
            ],
          ),
    ];
  }

  void _onPiecePlaced(JigsawPiece piece, Offset pieceDropPosition) {
    final RenderBox box = _boardWidgetKey.currentContext.findRenderObject();
    final boardPosition = box.localToGlobal(Offset.zero);
    final targetPosition =
        boardPosition.translate(piece.boundary.left, piece.boundary.top);

    const threshold = 48.0;

    final distance = (pieceDropPosition - targetPosition).distance;
    if (distance < threshold) {
      setState(() {
        _currentPiece = piece;
        pieceOnPool.remove(piece);
      });
      _offsetAnimation = Tween<Offset>(
        begin: pieceDropPosition,
        end: targetPosition,
      ).animate(_animController);

      _animController.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            pieceOnBoard.add(piece);
            _currentPiece = null;
          });
        }
      });
      const spring = SpringDescription(
        mass: 30,
        stiffness: 1,
        damping: 1,
      );

      final simulation = SpringSimulation(spring, 0, 1, -distance);

      _animController.animateWith(simulation);
    }
  }
}

class JigsawPiece extends StatelessWidget {
  JigsawPiece({
    Key key,
    @required this.image,
    this.points,
    this.imageSize,
  })  : assert(points != null && points.length > 0),
        boundary = _getBounds(points),
        super(key: key);

  final Rect boundary;
  final ui.Image image;
  final List<Offset> points;
  final Size imageSize;

  Size get size => boundary.size;

  @override
  Widget build(BuildContext context) {
    final pixelScale = MediaQuery.of(context).devicePixelRatio;

    return CustomPaint(
      painter: JigsawPainter(
        image: image,
        boundary: boundary,
        points: points,
        pixelScale: pixelScale,
        elevation: 0,
      ),
      size: size,
    );
  }

  static Rect _getBounds(List<Offset> points) {
    final pointsX = points.map((e) => e.dx);
    final pointsY = points.map((e) => e.dy);
    return Rect.fromLTRB(
      pointsX.reduce(min),
      pointsY.reduce(min),
      pointsX.reduce(max),
      pointsY.reduce(max),
    );
  }
}

class JigsawPainter extends CustomPainter {
  final ui.Image image;
  final List<Offset> points;
  final Rect boundary;
  final double pixelScale;
  final double elevation;

  const JigsawPainter({
    @required this.image,
    @required this.points,
    @required this.boundary,
    @required this.pixelScale,
    this.elevation = 0,
  });

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final paint = Paint();
    final path = getClip(size);
    if (elevation > 0) {
      canvas.drawShadow(path, Colors.black, elevation, false);
    }

    canvas.clipPath(path);
    canvas.drawImageRect(
        image,
        Rect.fromLTRB(boundary.left * pixelScale, boundary.top * pixelScale,
            boundary.right * pixelScale, boundary.bottom * pixelScale),
        Rect.fromLTWH(0, 0, boundary.width, boundary.height),
        paint);
  }

  Path getClip(Size size) {
    final path = Path();
//    print("Points");
    for (var point in points) {
//      print('${point.dx - boundary.left}, ${point.dy - boundary.top}');
      if (points.indexOf(point) == 0) {
        path.moveTo(point.dx - boundary.left, point.dy - boundary.top);
      } else {
        path.lineTo(point.dx - boundary.left, point.dy - boundary.top);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(oldDelegate) => true;
}
