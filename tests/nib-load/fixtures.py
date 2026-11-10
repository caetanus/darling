#!/usr/bin/env python3
"""OSXER NIB (fixtures): original synthetic vectors from the brief's format.
No sample bytes or third-party app resources are included.
"""
import argparse
from pathlib import Path
import plistlib
import struct


def varint(n):
    b = bytearray()
    while n >= 128:
        b.append(n & 127)
        n >>= 7
    b.append(n | 128)
    return bytes(b)


def archive(objects, fallbacks=None, coder=10):
    classes = list(dict.fromkeys(c for c, _ in objects))
    keys = list(dict.fromkeys(k for _, vs in objects for k, t, v in vs))
    tables = [bytearray() for _ in range(4)]
    value_index = 0
    for c, values in objects:
        tables[0] += varint(classes.index(c)) + varint(value_index) + varint(len(values))
        value_index += len(values)
        for k, t, v in values:
            tables[2] += varint(keys.index(k)) + bytes([t])
            fmt = {0: '<b', 1: '<h', 2: '<i', 3: '<q', 6: '<f', 7: '<d', 10: '<I'}.get(t)
            if fmt:
                tables[2] += struct.pack(fmt, v)
            elif t == 8:
                tables[2] += varint(len(v)) + v
    for k in keys:
        b = k.encode()
        tables[1] += varint(len(b)) + b
    for c in classes:
        b = c.encode() + b'\0'
        fallback = (fallbacks or {}).get(c, [])
        tables[3] += varint(len(b)) + varint(len(fallback))
        for f in fallback:
            tables[3] += struct.pack('<I', classes.index(f))
        tables[3] += b
    counts = [len(objects), len(keys), value_index, len(classes)]
    header = b'NIBArchive' + struct.pack('<II', 1, coder)
    offset = 50
    for count, table in zip(counts, tables):
        header += struct.pack('<II', count, offset)
        offset += len(table)
    return header + b''.join(tables)


def ref(k, i): return (k, 10, i)
def string(s): return ('NSString', [('NS.bytes', 8, s.encode())])
def collection(c, items): return (c, [('NSInlinedValue', 5, True)] + [ref('UINibEncoderEmptyKey', i) for i in items])


def fixtures(output):
    output.mkdir(parents=True, exist_ok=True)
    objects = [
        ('NSObject', [ref(k, i) for k, i in [('root', 1), ('again', 1), ('array', 2), ('dict', 3), ('set', 4),
                                              ('string', 5), ('number', 6), ('data', 7), ('value', 8), ('swap', 9), ('fallback', 10)]]),
        ('NibCycle', [ref('self', 1), ('duplicate', 0, 42), ('duplicate', 0, 99),
                      ('i8', 0, -7), ('i16', 1, -1234), ('i32', 2, -1234567), ('i64', 3, -(1 << 40)),
                      ('false', 4, False), ('true', 5, True), ('float', 6, 1.25), ('double', 7, 2.5),
                      ('bytes', 8, b'A\0B'), ('nil', 9, None), ref('point', 11), ref('size', 12), ref('rect', 13)]),
        collection('NSMutableArray', [5, 1, 5]), collection('NSDictionary', [5, 6]), collection('NSSet', [5, 6]),
        string('Olá'), ('NSNumber', [('NS.intval', 3, 1 << 40)]), ('NSData', [('NS.bytes', 8, b'ABC\0DEF')]),
        ('NSValue', [('NS.special', 0, 2), ref('NS.sizeval', 12)]), ('NibSwap', [ref('self', 9)]),
        ('MissingNibClass', []), string('{3, 4}'), string('{5, 6}'), string('{{1, 2}, {3, 4}}'),
        ('NibFallback', []),
    ]
    valid = archive(objects, {'MissingNibClass': ['NibFallback']})
    (output / 'values.nib').write_bytes(valid)
    (output / 'coder9.nib').write_bytes(archive(objects, {'MissingNibClass': ['NibFallback']}, 9))
    malformed = {
        'truncated-header': valid[:15], 'truncated-data': valid[:-1],
        'bad-version': valid[:10] + struct.pack('<I', 2) + valid[14:],
        'bad-offset': valid[:22] + struct.pack('<I', 0xffffffff) + valid[26:],
        'bad-reference': archive([('NSObject', [ref('root', 99)])]),
        'odd-dictionary': archive([('NSObject', [ref('root', 1)]), collection('NSDictionary', [2]), string('key')]),
        'unknown-class': archive([('NSObject', [ref('root', 1)]), ('MissingNibClass', [])]),
        'invalid-utf8': archive([('NSObject', [ref('root', 1)]), ('NSString', [('NS.bytes', 8, b'\xff')])]),
        'bad-varint': valid[:50] + b'\x7f\x7f\x7f\x7f\x7f' + valid[55:],
        'unknown-type': archive([('NSObject', [('root', 255, None)])]),
    }
    for name, data in malformed.items(): (output / (name + '.nib')).write_bytes(data)
    # The controller is connected through the same sceneController outlet seen
    # in compiled storyboard samples. The view is a separate owner-connected nib.
    def scene(view=False):
        return archive([
            ('NSObject', [ref('IB.objectdata', 1)]),
            ('NSIBObjectData', [ref('NSRoot', 2), ref('NSConnections', 3), ref('NSObjectsKeys', 4),
                               ref('NSObjectsValues', 5), ref('NSVisibleWindows', 6)]),
            ('NSCustomObject', [ref('NSClassName', 7)]), collection('NSMutableArray', [8, 9] if not view else [8]),
            collection('NSMutableArray', [10]), collection('NSMutableArray', [2]), collection('NSMutableSet', []),
            string('NSObject'), ('NSNibOutletConnector', [ref('NSSource', 18 if view else 2), ref('NSDestination', 10), ref('NSLabel', 11)]),
            ('NSNibOutletConnector', [ref('NSSource', 10), ref('NSDestination', 12), ref('NSLabel', 13)]),
            ('NSView', [('NSFrame', 10, 14)]) if view else ('NSViewController', [ref('NSNibName', 14), ref('NSExternalObjectsTableForViewLoading', 16)]),
            string('view' if view else 'sceneController'),
            ('NSNibExternalObjectPlaceholder', [ref('NSExternalObjectPlaceholderIdentifier', 15)]),
            string('storyboard'), string('{{0, 0}, {80, 60}}' if view else 'SceneView'), string('NSStoryboardPlaceholder'),
            collection('NSDictionary', [17, 10]), string('UpstreamPlaceholder-1'),
            ('NSNibExternalObjectPlaceholder', [ref('NSExternalObjectPlaceholderIdentifier', 17)]),
        ])
    board = output / 'Synthetic.storyboardc'
    board.mkdir(exist_ok=True)
    (board / 'Info.plist').write_bytes(plistlib.dumps({'NSStoryboardVersion': 1,
        'NSStoryboardDesignatedEntryPointIdentifier': 'Scene', 'NSViewControllerIdentifiersToNibNames': {'Scene': 'Scene'},
        'NSStoryboardMainMenu': 'MainMenu'}))
    (board / 'Scene.nib').write_bytes(scene())
    (board / 'SceneView.nib').write_bytes(scene(True))
    window = archive([
        ('NSObject', [ref('IB.objectdata', 1)]),
        ('NSIBObjectData', [ref('NSRoot', 2), ref('NSConnections', 3), ref('NSObjectsKeys', 4),
                           ref('NSObjectsValues', 5), ref('NSVisibleWindows', 6)]),
        ('NSCustomObject', [ref('NSClassName', 7)]), collection('NSMutableArray', [8, 9]),
        collection('NSMutableArray', [10]), collection('NSMutableArray', [2]), collection('NSMutableSet', []),
        string('NSObject'), ('NSNibOutletConnector', [ref('NSSource', 2), ref('NSDestination', 10), ref('NSLabel', 11)]),
        ('NSNibOutletConnector', [ref('NSSource', 10), ref('NSDestination', 12), ref('NSLabel', 13)]),
        ('NSWindowController', [ref('IBWindowTemplate', 14), ref('IBWindowTemplateContentViewController', 15)]),
        string('sceneController'), ('NSNibExternalObjectPlaceholder', [ref('NSExternalObjectPlaceholderIdentifier', 16)]),
        string('storyboard'),
        ('NSWindowTemplate', [ref('NSWindowClass', 17), ref('NSWindowRect', 18), ref('NSWindowTitle', 19),
                              ('NSWindowStyleMask', 0, 1), ('NSWindowBacking', 0, 2), ref('NSWindowView', 20)]),
        ('NSViewController', [ref('NSNibName', 21), ref('NSExternalObjectsTableForViewLoading', 22)]),
        string('NSStoryboardPlaceholder'), string('NSWindow'), string('{{10, 10}, {80, 60}}'), string('Synthetic Window'),
        ('NSView', [ref('NSFrame', 18)]), string('SceneView'), collection('NSDictionary', [23, 15]),
        string('UpstreamPlaceholder-1'),
    ])
    (board / 'Window.nib').write_bytes(window)
    info = plistlib.loads((board / 'Info.plist').read_bytes())
    info['NSViewControllerIdentifiersToNibNames']['Window'] = 'Window'
    (board / 'Info.plist').write_bytes(plistlib.dumps(info))
    # Original keyed-bplist fixture exercises NSNib's unchanged legacy path.
    uid = plistlib.UID
    legacy_objects = [
        '$null',
        {'$class': uid(2), 'NSRoot': uid(3), 'NSObjectsKeys': uid(5), 'NSObjectsValues': uid(6),
         'NSConnections': uid(7), 'NSVisibleWindows': uid(8)},
        {'$classname': 'NSIBObjectData', '$classes': ['NSIBObjectData', 'NSObject']},
        {'$class': uid(11), 'NSClassName': uid(4)}, 'NSObject',
        {'$class': uid(9), 'NS.objects': [uid(10)]},
        {'$class': uid(9), 'NS.objects': [uid(3)]},
        {'$class': uid(9), 'NS.objects': []},
        {'$class': uid(12), 'NS.objects': []},
        {'$classname': 'NSArray', '$classes': ['NSArray', 'NSObject']}, 'legacy-top',
        {'$classname': 'NSCustomObject', '$classes': ['NSCustomObject', 'NSObject']},
        {'$classname': 'NSMutableSet', '$classes': ['NSMutableSet', 'NSSet', 'NSObject']},
    ]
    (output / 'Legacy.nib').write_bytes(plistlib.dumps({'$version': 100000, '$archiver': 'NSKeyedArchiver',
        '$top': {'IB.objectdata': uid(1)}, '$objects': legacy_objects}, fmt=plistlib.FMT_BINARY))
    (output / 'flat.nib').write_bytes(scene())
    variant = output / 'Variant.nib'
    variant.mkdir(exist_ok=True)
    (variant / 'keyedobjects-101300.nib').write_bytes(scene())


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    fixtures(parser.parse_args().output)
