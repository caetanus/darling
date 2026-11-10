#!/usr/bin/env python3
"""OSXER APPKIT (table nib fixtures): synthetic archives, no application resources."""
from pathlib import Path
import runpy
import sys
sys.dont_write_bytecode = True
helpers = runpy.run_path(str(Path(__file__).resolve().parent.parent / 'nib-load/fixtures.py'))
archive, ref, string, collection = (helpers[k] for k in ('archive', 'ref', 'string', 'collection'))
output = Path(sys.argv[1])
output.mkdir(parents=True, exist_ok=True)
# Cell + text outlet + explicit value binding + owner's outlet. NSIBObjectData
# uses parent relationships to distinguish roots from a cell's owned subviews.
cell = archive([
    ('NSObject', [ref('IB.objectdata', 1)]),
    ('NSIBObjectData', [ref('NSRoot', 2), ref('NSConnections', 3), ref('NSObjectsKeys', 4), ref('NSObjectsValues', 5)]),
    ('NSCustomObject', [ref('NSClassName', 6)]), collection('NSMutableArray', [12, 13, 14]),
    collection('NSMutableArray', [7, 8]), collection('NSMutableArray', [2, 7]), string('NSObject'),
    ('NSTableCellView', [ref('NSFrame', 9), ref('NSSubviews', 10), ref('NSUserInterfaceItemIdentifier', 11)]),
    ('NSTextField', [ref('NSFrame', 9), ref('NSCell', 19)]), string('{{0, 0}, {90, 20}}'),
    collection('NSMutableArray', [8]), string('cell'),
    ('NSNibOutletConnector', [ref('NSSource', 7), ref('NSDestination', 8), ref('NSLabel', 15)]),
    ('NSNibOutletConnector', [ref('NSSource', 2), ref('NSDestination', 7), ref('NSLabel', 16)]),
    ('NSNibBindingConnector', [('NSNibBindingConnectorVersion', 2, 2), ref('NSSource', 8), ref('NSDestination', 7), ref('NSBinding', 17), ref('NSKeyPath', 18)]),
    string('textField'), string('lastCell'), string('value'), string('objectValue'),
    ('NSTextFieldCell', [ref('NSContents', 20)]), string(''),
])
(output / 'cell.nib').write_bytes(cell)
table = archive([
    ('NSObject', [ref('IB.objectdata', 1)]),
    ('NSIBObjectData', [ref('NSRoot', 2), ref('NSConnections', 3), ref('NSObjectsKeys', 4), ref('NSObjectsValues', 5)]),
    ('NSCustomObject', [ref('NSClassName', 6)]), collection('NSMutableArray', [15]),
    collection('NSMutableArray', [7]), collection('NSMutableArray', [2]), string('NSObject'),
    ('NSTableView', [ref('NSFrame', 8), ref('NSTableColumns', 9), ('NSRowHeight', 6, 24),
                     ref('NSTableViewArchivedReusableViewsKey', 11)]), string('{{0, 0}, {100, 60}}'),
    collection('NSMutableArray', [10]),
    ('NSTableColumn', [ref('NSIdentifier', 12), ('NSWidth', 6, 100), ('NSMinWidth', 6, 10), ('NSMaxWidth', 6, 1000)]),
    collection('NSDictionary', [12, 13]), string('cell'),
    ('NSNib', [ref('NSNibFileData', 14), ('NSNibFileIsKeyed', 5, True)]), ('NSData', [('NS.bytes', 8, cell)]),
    ('NSNibOutletConnector', [ref('NSSource', 2), ref('NSDestination', 7), ref('NSLabel', 16)]), string('table'),
])
(output / 'table.nib').write_bytes(table)
print('Generated cell.nib and table.nib')
