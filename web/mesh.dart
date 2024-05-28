import 'dart:async';
import 'dart:convert';
import 'dart:html' as HTML;
import 'dart:typed_data';

import 'package:chronosgl/chronosgl.dart';

import 'glutil.dart';

import 'assets.dart' as assets;

// Parse the chunks in a glTF file.
Map<String, ByteData> _parseChunks(ByteData data) {
  if (data.lengthInBytes < 12) {
    throw 'Not a glTF file';
  }
  final magic = ascii.decode(Uint8List.sublistView(data, 0, 4));
  if (magic != 'glTF') {
    throw 'Not a glTF file';
  }
  final length = data.getUint32(8, Endian.little);
  if (length > data.lengthInBytes) {
    throw 'Incomplete file';
  }
  int pos = 12;
  final Map<String, ByteData> chunks = {};
  while (pos < length) {
    if (8 > length - pos) {
      throw 'Invalid glTF: Chunk too short';
    }
    final chunkLength = data.getUint32(pos, Endian.little);
    final chunkID = ascii.decode(Uint8List.sublistView(data, pos + 4, pos + 8));
    pos += 8;
    if ((chunkLength & 3) != 0) {
      throw 'Invalid glTF: Unaligned chunk';
    }
    if (chunks.containsKey(chunkID)) {
      throw 'Invalid glTF: Duplicate chunk';
    }
    if (chunkLength > length - pos) {
      throw 'Invalid glTF: Chunk out of bounds';
    }
    chunks[chunkID] = ByteData.sublistView(data, pos, pos + chunkLength);
    pos += chunkLength;
  }
  return chunks;
}

// A single part of a mesh with a single material.
class MeshPart {
  final String material;
  final Uint16List _index;
  final Float32List _position;
  final Float32List? _texCoord;
  final Float32List? _normal;

  MeshPart(
      this.material, this._index, this._position, this._texCoord, this._normal);

  MeshData build(String name, RenderProgram prog) {
    final data = prog.MakeMeshData(name, GL_TRIANGLES);
    data.AddVertices(_position);
    if (_texCoord != null) {
      data.AddAttribute(aTexUV, _texCoord!, 2);
    }
    if (_normal != null) {
      data.AddAttribute(aNormal, _normal!, 3);
    }
    data.AddFaces(_index);
    return data;
  }
}

class _Accessor {
  final ByteData bufferView;
  final Map<String, dynamic> info;

  _Accessor(this.bufferView, this.info);

  void checkType(String expectedType) {
    final String type = info['type'];
    if (type != expectedType) {
      throw "Attribute has wrong type: ${json.encode(type)} (should be $expectedType)";
    }
  }

  Float32List attribute(String expectedType) {
    checkType(expectedType);
    final int componentType = info['componentType'];
    if (componentType != GL_FLOAT) {
      throw "Attribute has wrong component type: ${typeName(componentType)} (should be float)";
    }
    return Float32List.sublistView(bufferView);
  }

  Uint16List indexes() {
    checkType("SCALAR");
    final int componentType = info['componentType'];
    if (componentType != GL_UNSIGNED_SHORT) {
      throw "Attribute has wrong component type: ${typeName(componentType)}";
    }
    return Uint16List.sublistView(bufferView);
  }
}

// A mesh, consisting of one or more parts.
class Mesh {
  final String name;
  final List<MeshPart> parts;

  Mesh(this.name, this.parts);

  static Future<List<Mesh>> load(String url) {
    return assets.getData(url).then((data) {
      // glTF (in the glb version) is two chunks: JSON and binary.
      final chunks = _parseChunks(ByteData.sublistView(data));
      final jsonData = chunks['JSON'];
      if (jsonData == null) {
        throw 'Missing glTF JSON chunk';
      }
      final binData = chunks['BIN\u0000'];
      if (binData == null) {
        throw 'Missing glTF binary chunk';
      }

      Map<String, dynamic> info =
          json.decode(utf8.decode(Uint8List.sublistView(jsonData)));
      List<String> materials = [];
      for (Map<String, dynamic> material in info['materials']) {
        materials.add(material['name'] ?? '');
      }
      List<ByteData> buffers = [];
      for (Map<String, dynamic> buffer in info['buffers']) {
        if (buffer.containsKey('uri')) {
          throw 'External glTF data';
        }
        buffers.add(ByteData.sublistView(binData, 0, buffer['byteLength']));
      }
      List<ByteData> bufferViews = [];
      for (Map<String, dynamic> view in info['bufferViews']) {
        ByteData buffer = buffers[view['buffer']];
        int byteOffset = view['byteOffset'] ?? 0;
        int byteLength = view['byteLength'];
        if (view.containsKey('byteStride')) {
          throw 'Buffer has stride, not supported';
        }
        bufferViews.add(
            ByteData.sublistView(buffer, byteOffset, byteOffset + byteLength));
      }
      List<_Accessor> accessors = [];
      for (Map<String, dynamic> accessor in info['accessors']) {
        ByteData bufferView = bufferViews[accessor['bufferView']];
        accessors.add(_Accessor(bufferView, accessor));
      }
      List<Mesh> meshes = [];
      for (Map<String, dynamic> mesh in info['meshes']) {
        String name = mesh['name'] ?? 'unknown mesh';
        List<MeshPart> parts = [];
        for (Map<String, dynamic> primitive in mesh['primitives']) {
          String material = materials[primitive['material']];
          Uint16List indexes = accessors[primitive['indices']].indexes();
          Map<String, dynamic> attributes = primitive['attributes'];
          int? aPosition = attributes['POSITION'];
          int? aTexCoord = attributes['TEXCOORD_0'];
          int? aNormal = attributes['NORMAL'];
          if (aPosition == null) {
            throw 'No position attribute';
          }
          Float32List position = accessors[aPosition].attribute("VEC3");
          Float32List? texCoord =
              aTexCoord != null ? accessors[aTexCoord].attribute("VEC2") : null;
          Float32List? normal =
              aNormal != null ? accessors[aNormal].attribute("VEC3") : null;
          parts.add(MeshPart(material, indexes, position, texCoord, normal));
        }
        meshes.add(Mesh(name, parts));
      }
      return meshes;
    });
  }
}
