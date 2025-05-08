import 'dart:async';
import 'dart:math';

import 'package:ble_backend/ble_connector.dart';
import 'package:ble_backend/ble_peripheral.dart';
import 'package:ble_backend_screens/ui/ui_consts.dart';
import 'package:ble_chess_example/options_screen.dart';
import 'package:ble_chess_peripheral_driver/ble_chess_peripheral_driver.dart';
import 'package:ble_chess_peripheral_driver/chess_peripheral_driver.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'board_theme.dart';
import 'peripheral_fen.dart';

class RoundScreen extends StatefulWidget {
  RoundScreen({
    required this.bleConnector,
    required this.blePeripheral,
    super.key,
  });

  final BleConnector bleConnector;
  final BlePeripheral blePeripheral;

  @override
  State<RoundScreen> createState() => RoundScreenState();
}

enum Mode {
  botPlay,
  freePlay,
}

class RoundScreenState extends State<RoundScreen> {
  StreamSubscription? _subscription;
  Peripheral peripheral = DummyPeripheral();
  bool isAutocompleteOngoing = false;
  Position position = Chess.initial;
  Side orientation = Side.white;
  String fen = kInitialBoardFEN;
  NormalMove? lastMove;
  NormalMove? promotionMove;
  NormalMove? premove;
  ValidMoves validMoves = IMap(const {});
  Side sideToMove = Side.white;
  PieceSet pieceSet = PieceSet.gioco;
  PieceShiftMethod pieceShiftMethod = PieceShiftMethod.either;
  DragTargetKind dragTargetKind = DragTargetKind.circle;
  BoardTheme boardTheme = BoardTheme.brown;
  bool drawMode = true;
  bool pieceAnimation = true;
  bool dragMagnify = true;
  Mode playMode = Mode.freePlay;
  Position? lastPos;
  ISet<Shape> shapes = ISet();
  bool showBorder = false;

  BlePeripheral get blePeripheral => widget.blePeripheral;
  BleConnector get bleConnector => widget.bleConnector;

  void _beginNewRound() {
    setState(() {
      position = Chess.initial;
      fen = position.fen;
      validMoves = makeLegalMoves(position);
      lastMove = null;
      lastPos = null;
    });
    () async {
      await _showChoicesPicker<Mode>(
        context,
        choices: Mode.values,
        selectedItem: playMode,
        labelBuilder: (t) => Text(t.name),
        onSelectedItemChanged: (Mode value) {
          setState(() {
            playMode = value;
          });
        },
      );
      await peripheral.handleBegin(
        fen: fen,
        variant: Variants.standard,
        side: playMode == Mode.botPlay ? Sides.white : Sides.both,
        lastMove: lastMove?.uci,
      );
    }.call();
  }

  void _showMessage(String msg) {
    Fluttertoast.showToast(msg: msg, fontSize: 18.0);
  }

  void _showError(String err) {
    Fluttertoast.showToast(
      msg: err,
      toastLength: Toast.LENGTH_LONG,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      fontSize: 18.0,
    );
  }

  void _handlePeripheralInitialized(_) {
    setState(() {
      _beginNewRound();
    });
  }

  void _handlePeripheralRoundInitialized(_) {
    setState(() {
      isAutocompleteOngoing = false;
      if (!peripheral.round.isVariantSupported) {
        _showMessage('Unsupported variant');
      }
    });
  }

  void _handlePeripheralRoundUpdate(_) {
    setState(() {
      isAutocompleteOngoing = false;
    });
  }

  void _handlePeripheralStateSynchronize(bool isSynchronized) {
    _showMessage(isSynchronized ? 'Synchronized' : 'Unsynchronized');
  }

  void _handleCentralMove(NormalMove move) {
    peripheral.handleMove(move: move.uci);
    _handleCentralEnd();
  }

  void _handleCentralEnd() {
    if (position.isCheckmate) {
      _showMessage('Checkmate');
      peripheral.handleEnd(reason: EndReasons.checkmate);
    } else if (position.isStalemate) {
      _showMessage('Stalemate');
      peripheral.handleEnd(
        reason: EndReasons.draw,
        drawReason: DrawReasons.stalemate,
      );
    } else if (position.isInsufficientMaterial) {
      _showMessage('Insufficient material');
      peripheral.handleEnd(
        reason: EndReasons.draw,
        drawReason: DrawReasons.insufficientMaterial,
      );
    } else if (position.isVariantEnd) {
      _showMessage('Variant end');
      peripheral.handleEnd(reason: EndReasons.undefined);
    }
  }

  void _handlePeripheralMove(String uci) {
    final move = NormalMove.fromUci(uci);
    if (position.isLegal(move)) {
      playMode == Mode.botPlay ? _onUserMoveAgainstBot(move) : _playMove(move);
    } else {
      setState(() {
        peripheral.handleReject();
        _showMessage('Rejected');
      });
    }
  }

  void _handleAutocomplete() {
    setState(() {
      isAutocompleteOngoing = true;
      peripheral.handleSetState();
    });
  }

  Future<void> _initPeripheral() async {
    final mtu = bleConnector.createMtu();
    final requestedMtu = await mtu.request(mtu: maxStringSize);
    if (requestedMtu < maxStringSize) {
      bleConnector.disconnect();
      _showError(
        'Mtu: $requestedMtu, is less than the required: ${maxStringSize}',
      );
      return;
    }

    final serial = BleStringSerial(
      bleSerial: bleConnector.createSerial(
        serviceId: serviceUuid,
        rxCharacteristicId: characteristicUuidRx,
        txCharacteristicId: characteristicUuidTx,
      ),
    );
    final features = [
      Features.msg,
      Features.lastMove,
      Features.side,
      Features.setState,
      Features.stateStream,
      Features.drawReason,
      Features.option,
    ];
    final variants = [Variants.standard];
    peripheral = CppPeripheral(
      stringSerial: serial,
      features: features,
      variants: variants,
    );
    peripheral.initializedStream.listen(_handlePeripheralInitialized);
    peripheral.roundInitializedStream.listen(_handlePeripheralRoundInitialized);
    peripheral.roundUpdateStream.listen(_handlePeripheralRoundUpdate);
    peripheral.stateSynchronizeStream.listen(_handlePeripheralStateSynchronize);
    peripheral.moveStream.listen(_handlePeripheralMove);
    peripheral.errStream.listen(_showError);
    peripheral.msgStream.listen(_showMessage);
  }

  void _onConnectionStateChanged(BleConnectorStatus state) {
    setState(() {
      if (state == BleConnectorStatus.disconnected) {
        peripheral = DummyPeripheral();
      } else if (state == BleConnectorStatus.connected) {
        _initPeripheral();
      }
    });
  }

  void _tryPlayPremove() {
    if (premove != null) {
      Timer.run(() {
        _playMove(premove!, isPremove: true);
      });
    }
  }

  void _onCompleteShape(Shape shape) {
    if (shapes.any((element) => element == shape)) {
      setState(() {
        shapes = shapes.remove(shape);
      });
      return;
    } else {
      setState(() {
        shapes = shapes.add(shape);
      });
    }
  }

  Future<void> _showChoicesPicker<T extends Enum>(
    BuildContext context, {
    required List<T> choices,
    required T selectedItem,
    required Widget Function(T choice) labelBuilder,
    required void Function(T choice) onSelectedItemChanged,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          contentPadding: const EdgeInsets.only(top: 12),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: choices.map((value) {
              return RadioListTile<T>(
                title: labelBuilder(value),
                value: value,
                groupValue: selectedItem,
                onChanged: (value) {
                  if (value != null) onSelectedItemChanged(value);
                  Navigator.of(context).pop();
                },
              );
            }).toList(growable: false),
          ),
        );
      },
    );
  }

  void _onSetPremove(NormalMove? move) {
    setState(() {
      premove = move;
    });
  }

  void _onPromotionSelection(Role? role) {
    if (role == null) {
      _onPromotionCancel();
    } else if (promotionMove != null) {
      if (playMode == Mode.botPlay) {
        _onUserMoveAgainstBot(promotionMove!.withPromotion(role));
      } else {
        _playMove(promotionMove!.withPromotion(role));
      }
    }
  }

  void _onPromotionCancel() {
    setState(() {
      promotionMove = null;
    });
  }

  void _playMove(NormalMove move, {bool? isDrop, bool? isPremove}) {
    lastPos = position;
    if (isPromotionPawnMove(move)) {
      setState(() {
        promotionMove = move;
      });
    } else if (position.isLegal(move)) {
      setState(() {
        position = position.playUnchecked(move);
        lastMove = move;
        fen = position.fen;
        validMoves = makeLegalMoves(position);
        promotionMove = null;
        if (isPremove == true) {
          premove = null;
        }
        _handleCentralMove(move);
      });
    }
  }

  void _onUserMoveAgainstBot(NormalMove move, {isDrop}) async {
    lastPos = position;
    if (isPromotionPawnMove(move)) {
      setState(() {
        promotionMove = move;
      });
    } else {
      setState(() {
        position = position.playUnchecked(move);
        lastMove = move;
        fen = position.fen;
        validMoves = IMap(const {});
        promotionMove = null;
      });
      _handleCentralMove(move);
      await _playBlackMove();
      _tryPlayPremove();
    }
  }

  Future<void> _playBlackMove() async {
    Future.delayed(const Duration(milliseconds: 100)).then((value) {
      setState(() {});
    });
    if (position.isGameOver) return;

    final random = Random();
    await Future.delayed(Duration(milliseconds: random.nextInt(1000) + 500));
    final allMoves = [
      for (final entry in position.legalMoves.entries)
        for (final dest in entry.value.squares)
          NormalMove(from: entry.key, to: dest)
    ];
    if (allMoves.isNotEmpty) {
      NormalMove mv = (allMoves..shuffle()).first;
      // Auto promote to a random non-pawn role
      if (isPromotionPawnMove(mv)) {
        final potentialRoles =
            Role.values.where((role) => role != Role.pawn).toList();
        final role = potentialRoles[random.nextInt(potentialRoles.length)];
        mv = mv.withPromotion(role);
      }

      setState(() {
        position = position.playUnchecked(mv);
        lastMove =
            NormalMove(from: mv.from, to: mv.to, promotion: mv.promotion);
        fen = position.fen;
        validMoves = makeLegalMoves(position);
      });
      lastPos = position;
      _handleCentralMove(mv);
    }
  }

  bool isPromotionPawnMove(NormalMove move) {
    return move.promotion == null &&
        position.board.roleAt(move.from) == Role.pawn &&
        ((move.to.rank == Rank.first && position.turn == Side.black) ||
            (move.to.rank == Rank.eighth && position.turn == Side.white));
  }

  @override
  void initState() {
    super.initState();
    validMoves = makeLegalMoves(position);
    _subscription = bleConnector.stateStream.listen(_onConnectionStateChanged);
    bleConnector.connect();
  }

  @override
  void dispose() {
    () async {
      await bleConnector.disconnect();
      await _subscription?.cancel();
    }.call();
    bleConnector.dispose();
    super.dispose();
  }

  // String? get lastMove {
  //   final history = game.history;
  //   if (history.isEmpty) return null;
  //   final lastMove = history.last.move;
  //   String uci = lastMove.fromAlgebraic + lastMove.toAlgebraic;
  //   final promotion = lastMove.promotion;
  //   if (promotion != null) uci += promotion.name;
  //   return uci;
  // }

  // Widget _buildChessBoardWidget() => ChessBoard(
  //       controller: chessController,
  //       boardColor: BoardColor.darkBrown,
  //       boardOrientation: PlayerColor.white,
  //       onMove: _handleCentralMove,
  //     );

  IMap<Square, SquareHighlight> _createSquareHighlights() {
    const Color rejectedMoveColor = Color.fromRGBO(199, 0, 109, 0.41);
    const Color pieceRemoveColor = Color.fromRGBO(255, 60, 60, 0.50);
    const Color pieceAddColor = Color.fromRGBO(60, 255, 60, 0.50);
    const Color pieceReplaceColor = Color.fromRGBO(60, 60, 255, 0.50);
    IMap<Square, SquareHighlight> highlights = IMap();
    if (peripheral.round.rejectedMove != null) {
      final rejectedMove = NormalMove.fromUci(peripheral.round.rejectedMove!);
      highlights = highlights.add(
          rejectedMove.from,
          SquareHighlight(
            details: HighlightDetails(
              solidColor: rejectedMoveColor,
            ),
          ));
      highlights = highlights.add(
          rejectedMove.to,
          SquareHighlight(
            details: HighlightDetails(
              solidColor: rejectedMoveColor,
            ),
          ));
    }
    if (!peripheral.round.isStateSynchronized && peripheral.round.fen != null) {
      final peripheralPieces = readPeripheralFen(peripheral.round.fen!);
      final centralPieces = readFen(fen);
      for (final entry in centralPieces.entries) {
        final square = entry.key;
        final centralPiece = entry.value;
        final peripheralPiece = peripheralPieces[square];
        if (peripheralPiece == null) {
          highlights = highlights.add(
              square,
              SquareHighlight(
                details: HighlightDetails(
                  solidColor: pieceAddColor,
                ),
              ));
        } else if ((peripheralPiece.role != null &&
                peripheralPiece.role != centralPiece.role) ||
            (peripheralPiece.color != null &&
                peripheralPiece.color != centralPiece.color)) {
          highlights = highlights.add(
              square,
              SquareHighlight(
                details: HighlightDetails(
                  solidColor: pieceReplaceColor,
                ),
              ));
        }
      }
      for (final entry in peripheralPieces.entries) {
        final square = entry.key;
        final centralPiece = centralPieces[square];
        if (centralPiece == null) {
          highlights = highlights.add(
              square,
              SquareHighlight(
                details: HighlightDetails(
                  solidColor: pieceRemoveColor,
                ),
              ));
        }
      }
    }
    return highlights;
  }

  Widget _buildChessBoardWidget() => Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Chessboard(
              size: min(constraints.maxWidth, constraints.maxHeight),
              settings: ChessboardSettings(
                pieceAssets: pieceSet.assets,
                colorScheme: boardTheme.colors,
                border: showBorder
                    ? BoardBorder(
                        width: 16.0,
                        color: _darken(boardTheme.colors.darkSquare, 0.2),
                      )
                    : null,
                enableCoordinates: true,
                animationDuration: pieceAnimation
                    ? const Duration(milliseconds: 200)
                    : Duration.zero,
                dragFeedbackScale: dragMagnify ? 2.0 : 1.0,
                dragTargetKind: dragTargetKind,
                drawShape: DrawShapeOptions(
                  enable: drawMode,
                  onCompleteShape: _onCompleteShape,
                  onClearShapes: () {
                    setState(() {
                      shapes = ISet();
                    });
                  },
                ),
                pieceShiftMethod: pieceShiftMethod,
                autoQueenPromotionOnPremove: false,
                pieceOrientationBehavior: playMode == Mode.freePlay
                    ? PieceOrientationBehavior.opponentUpsideDown
                    : PieceOrientationBehavior.facingUser,
              ),
              orientation: orientation,
              fen: fen,
              lastMove: peripheral.round.isStateSynchronized ? lastMove : null,
              squareHighlights: _createSquareHighlights(),
              game: GameData(
                playerSide: playMode == Mode.botPlay
                    ? PlayerSide.white
                    : (position.turn == Side.white
                        ? PlayerSide.white
                        : PlayerSide.black),
                validMoves: validMoves,
                sideToMove:
                    position.turn == Side.white ? Side.white : Side.black,
                isCheck: peripheral.round.isStateSynchronized
                    ? position.isCheck
                    : false,
                promotionMove: promotionMove,
                onMove: playMode == Mode.botPlay
                    ? _onUserMoveAgainstBot
                    : _playMove,
                onPromotionSelection: _onPromotionSelection,
                premovable: (
                  onSetPremove: _onSetPremove,
                  premove: premove,
                ),
              ),
              shapes: shapes.isNotEmpty ? shapes : null,
            );
          },
        ),
      );

  Widget _buildNewRoundButton() => FilledButton.icon(
        icon: const Icon(Icons.refresh_rounded),
        label: Text('New Round'),
        onPressed: peripheral.isInitialized ? _beginNewRound : null,
      );

  Widget _buildAutocompleteButton() => FilledButton.icon(
        icon: const Icon(Icons.auto_awesome_rounded),
        label: Text('Autocomplete'),
        onPressed: peripheral.round.isStateSetible && !isAutocompleteOngoing
            ? _handleAutocomplete
            : null,
      );

  Widget _buildControlButtons() => SizedBox(
        height: buttonHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _buildNewRoundButton()),
            if (peripheral.isFeatureSupported(Features.setState))
              const SizedBox(width: buttonsSplitter),
            if (peripheral.isFeatureSupported(Features.setState))
              Expanded(child: _buildAutocompleteButton()),
          ],
        ),
      );

  Widget _buildPortrait() => Padding(
        padding: EdgeInsets.symmetric(vertical: screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: Center(child: _buildChessBoardWidget())),
            const SizedBox(height: screenPortraitSplitter),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: screenPadding),
              child: _buildControlButtons(),
            ),
          ],
        ),
      );

  Widget _buildLandscape() => Padding(
        padding: const EdgeInsets.all(screenPadding),
        child: Row(
          children: [
            Expanded(child: Center(child: _buildChessBoardWidget())),
            const SizedBox(width: screenLandscapeSplitter),
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _buildControlButtons(),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        primary: MediaQuery.of(context).orientation == Orientation.portrait,
        appBar: AppBar(
          title: Text(blePeripheral.name ?? ''),
          centerTitle: true,
          actions: [
            if (peripheral.isFeatureSupported(Features.option))
              IconButton(
                icon: const Icon(Icons.settings_rounded),
                onPressed: peripheral.isInitialized
                    ? () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                OptionsScreen(peripheral: peripheral),
                          ),
                        );
                      }
                    : null,
              ),
          ],
        ),
        body: SafeArea(
          child: OrientationBuilder(
            builder: (context, orientation) =>
                orientation == Orientation.portrait
                    ? _buildPortrait()
                    : _buildLandscape(),
          ),
        ),
      );
}

Color _darken(Color c, [double amount = .1]) {
  assert(amount >= 0 && amount <= 1);
  return Color.lerp(c, const Color(0xFF000000), amount) ?? c;
}
