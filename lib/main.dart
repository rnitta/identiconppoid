import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker_saver/image_picker_saver.dart';
import 'package:image/image.dart' as imagep;
import 'package:crypto/crypto.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Identiconppoid',
      theme: ThemeData.dark(),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Identiconppoid'),
        ),
        body: Home(),
        resizeToAvoidBottomPadding: false,
      ),
    );
  }
}

class IdenticonState extends Model {
  String seed;
  Color color;
  List<int> digest;
  List<bool> field;

  IdenticonState() {
    update('');
  }

  void update(String str) {
    seed = str;
    digest = md5.convert(utf8.encode(seed)).bytes;
    color = _color(digest);
    field = _field(digest);
    notifyListeners();
  }

  List<bool> _field(List<int> dig) {
//    return List<bool>.generate(25, (i) {
//      final int offset = ((i ~/ 5)) * 5;
//      final index = (((i - offset - 2).abs() * 5 + (i ~/ 5)));
//      return (((dig[index ~/ 2] & (0xf << (4 - (index % 2) * 4))) % 2) == 0);
//    });

    // https://github.com/dgraham/identicon/blob/faae3c50180cd37f3dc3e36925655f16b507097b/src/lib.rs#L53
    final ret = List<bool>.filled(25, false);
    final List<bool> paints = dig
        .fold<List<int>>(<int>[], (acc, cur) => acc..add(cur ~/ 0x10)..add(cur & 0xf))
        .map<bool>((i) => ((i % 2) == 0))
        .toList();
    int i = 0;
    for (int col = 2; col >= 0; col--) {
      for (int row = 0; row < 5; row++) {
        final int ix = col + (row * 5);
        final int mirrorCol = 4 - col;
        final int mirrorIx = mirrorCol + (row * 5);
        ret[ix] = paints[i];
        ret[mirrorIx] = paints[i];
        i++;
      }
    }
    return ret;
  }

  Color _color(List<int> dig) {
    final double hue = _map((((dig[12] & 0xf) << 8) | dig[13]), 0, 0xfff, 0, 360); // 色相
    final double sat = (65 - _map(dig[14], 0, 0xff, 0, 20)) / 100; // 彩度
    final double lig = (75 - _map(dig[15], 0, 0xff, 0, 20)) / 100; // 輝度
    return HSLColor.fromAHSL(1.0, hue, sat, lig).toColor();
  }

  double _map(int value, int vmin, int vmax, int dmin, int dmax) =>
      ((value - vmin) * (dmax - dmin)) / ((vmax - vmin) + dmin);
}

class Home extends StatelessWidget {
  final identiconState = IdenticonState();
  final gridKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    ScreenUtil.instance = ScreenUtil(width: 375, height: 667)..init(context);
    return ScopedModel<IdenticonState>(
        model: identiconState,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[_identiconGrid(), _textInput(), _saveButton()],
        ));
  }

  Widget _saveButton() {
    return FlatButton.icon(
        onPressed: () async {
          final RenderRepaintBoundary boundary = gridKey.currentContext.findRenderObject();
          final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
          final ByteData byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          final Uint8List pngBytes = byteData.buffer.asUint8List();
          final thumbnail = imagep.copyResize(imagep.decodeImage(pngBytes), 300);
          await ImagePickerSaver.saveFile(fileData: imagep.encodePng(thumbnail));
        },
        icon: Icon(Icons.save),
        label: Text('Save'));
  }

  Widget _textInput() {
    return Container(
        margin: EdgeInsets.only(top: ScreenUtil().setWidth(20)),
        width: ScreenUtil().setWidth(240),
        child: TextField(
          onChanged: (txt) {
            identiconState.update(txt);
          },
          cursorWidth: 5,
          autocorrect: false,
          decoration: InputDecoration(
            hintText: 'Input some text',
            labelText: "Seed Text",
          ),
        ));
  }

  Widget _identiconGrid() {
    return Center(
        child: Container(
            margin: EdgeInsets.only(top: ScreenUtil().setHeight(40)),
            child: Container(
                width: ScreenUtil().setWidth(200),
                height: ScreenUtil().setWidth(200),
                child: ScopedModelDescendant<IdenticonState>(
                    builder: (context, child, model) => RepaintBoundary(
                        key: gridKey,
                        child: Container(
                            padding: EdgeInsets.all(ScreenUtil().setWidth(20)),
                            color: Color.fromRGBO(240, 240, 240, 1.0),
                            child: GridView.count(
                              shrinkWrap: true,
                              primary: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 5,
                              children: List<Widget>.generate(
                                  25,
                                  (i) => Container(
                                        color: identiconState.field[i]
                                            ? identiconState.color
                                            : Color.fromRGBO(240, 240, 240, 1.0),
                                      )),
                            )))))));
  }
}
