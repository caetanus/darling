#!/usr/bin/env python3
"""OSXER NIB (class fixtures): original synthetic graphs; no app resources."""
from pathlib import Path
import plistlib
import runpy
import sys
sys.dont_write_bytecode = True
f = runpy.run_path(str(Path(__file__).with_name('fixtures.py')))
archive, ref, string, collection = (f[k] for k in ('archive', 'ref', 'string', 'collection'))


class Graph:
    def __init__(self): self.nodes = [('NSObject', [])]
    def add(self, cls, values=()):
        self.nodes.append((cls, list(values)))
        return len(self.nodes) - 1
    def text(self, value):
        self.nodes.append(string(value)); return len(self.nodes) - 1
    def array(self, values):
        self.nodes.append(collection('NSArray', values)); return len(self.nodes) - 1
    def dictionary(self, values):
        items = []
        for key, value in values.items(): items += [self.text(key), value]
        self.nodes.append(collection('NSDictionary', items)); return len(self.nodes) - 1
    def view(self, cls='NSView', values=(), frame='{{0, 0}, {160, 80}}'):
        return self.add(cls, [ref('NSFrame', self.text(frame)), ('NSvFlags', 2, 256), *values])
    def write(self, directory, name, root):
        self.nodes[0][1].append(ref('root', root))
        (directory / (name + '.nib')).write_bytes(archive(self.nodes))


def fixtures(output):
    output.mkdir(parents=True, exist_ok=True)
    cases = []
    def save(g, cls, root):
        g.write(output, cls, root); cases.append(cls)
    g=Graph(); save(g, 'NSLayoutGuide', g.add('NSLayoutGuide', [ref('NSLayoutGuideIdentifier',g.text('guide')), ('NSLayoutGuideLockedToOwningView',5,True)]))
    g=Graph(); save(g, 'IBNSViewAutolayoutGuide', g.add('IBNSViewAutolayoutGuide',[('IBNSLayoutGuideSystemType',0,1)]))
    g=Graph(); save(g, 'IBClassReference', g.add('IBClassReference',[ref('IBClassName',g.text('NSView')),ref('IBModuleName',g.text('AppKit')),ref('IBModuleProvider',g.text('AppKit'))]))
    g=Graph(); save(g, 'IBImageConfiguration',g.add('IBImageConfiguration',[ref('IBHierarchicalColors',g.array([])),('IBLocale',9,None),('IBRenderingMode',0,1),('IBSymbolScale',3,2),ref('IBVariableValue',g.add('NSNumber',[('NS.dblval',7,0.25)]))]))
    g=Graph(); save(g, 'NSTreeController',g.add('NSTreeController',[ref('NSTreeContentChildrenKey',g.text('children')),('NSEditable',5,True),('NSPreservesSelection',5,True),('NSAvoidsEmptySelection',4,False),('NSSelectsInsertedObjects',4,False)]))
    g=Graph(); save(g, 'NSAttributedString',g.add('NSAttributedString',[ref('NSString',g.text('synthetic')),ref('NSAttributes',g.dictionary({'TestAttribute':g.text('value')}))]))
    g=Graph(); save(g, 'NSLocale',g.add('NSLocale',[ref('NS.identifier',g.text('en_US_POSIX'))]))
    g=Graph(); save(g, 'NSSortDescriptor',g.add('NSSortDescriptor',[ref('NSKey',g.text('name')),('NSAscending',5,True),ref('NSSelector',g.text('compare:'))]))
    g=Graph(); save(g, 'NSDecimalNumberHandler',g.add('NSDecimalNumberHandler',[('NS.roundingmode',0,2),('NS.scale',1,3),('NS.raise.overflow',5,True)]))
    g=Graph(); save(g, 'NSDateFormatter',g.add('NSDateFormatter',[ref('NS.format',g.text('yyyy-MM-dd')),ref('NS.attributes',g.dictionary({}))]))
    g=Graph(); save(g, 'NSNumberFormatter',g.add('NSNumberFormatter',[('NS.allowsfloats',4,False),ref('NS.min',g.add('NSNumber',[('NS.intval',0,2)])),ref('NS.max',g.add('NSNumber',[('NS.intval',0,8)])),ref('NS.decimal',g.text('.'))]))
    g=Graph(); save(g, 'NSColorSpace',g.add('NSColorSpace',[('NSModel',0,0),('NSID',0,2)]))
    g=Graph(); save(g, 'NSFontDescriptor',g.add('NSFontDescriptor',[ref('NSFontDescriptorAttributes',g.dictionary({'NSFontNameAttribute':g.text('Helvetica')}))]))
    g=Graph(); save(g, 'NSCursor',g.add('NSCursor',[('NSCursorType',0,0),ref('NSHotSpot',g.text('{0, 0}'))]))
    g=Graph(); save(g, 'NSPanGestureRecognizer',g.add('NSPanGestureRecognizer',[ref('NSGestureRecognizer.action',g.text('perform:')),('NSGestureRecognizer.allowedTouchTypes',0,3),('NSPanGestureRecognizer.buttonMask',0,2),('NSPanGestureRecognizer.numberOfTouchesRequired',0,2)]))
    g=Graph(); save(g, 'NSPredicateEditorRowTemplate',g.add('NSPredicateEditorRowTemplate',[ref('NSPredicateTemplateViews',g.array([g.view()])),('NSPredicateTemplateModifier',0,0),('NSPredicateTemplateOptions',0,1)]))
    g=Graph(); save(g, 'NSPredicateEditor',g.view('NSPredicateEditor',[('NSRuleEditorSliceHeight',7,29.0),('NSRuleEditorNestingMode',0,2),('NSRuleEditorEditable',5,True),ref('NSPredicateTemplates',g.array([]))]))
    g=Graph(); save(g, '_NSRuleEditorViewUnboundRowHolder',g.add('_NSRuleEditorViewUnboundRowHolder',[ref('NSBoundArray',g.array([]))]))
    g=Graph(); save(g, '_NSCornerView',g.view('_NSCornerView'))
    g=Graph(); save(g, 'IBNSWindowController',g.add('IBNSWindowController',[]))
    g=Graph(); save(g, 'NSIBHelpConnector',g.add('NSIBHelpConnector',[ref('NSDestination',g.view()),ref('NSFile',g.text('SyntheticHelp')),ref('NSMarker',g.text('intro'))]))
    g=Graph(); save(g, 'NSNibAXAttributeConnector',g.add('NSNibAXAttributeConnector',[ref('AXDestinationArchiveKey',g.view()),ref('AXAttributeTypeArchiveKey',g.text('AXHelp')),ref('AXAttributeValueArchiveKey',g.text('Synthetic help'))]))
    g=Graph(); save(g, 'NSNibAuxiliaryActionConnector',g.add('NSNibAuxiliaryActionConnector',[ref('NSSource',g.view('NSTableView',[ref('NSTableColumns',g.array([]))])),ref('NSLabel',g.text('perform:')),ref('NSTrigger',g.text('doubleAction'))]))
    g=Graph(); save(g, 'NSComparisonPredicate',g.add('NSComparisonPredicate',[ref('NSLeftExpression',g.add('NSSelfExpression',[('NSExpressionType',0,1)])),ref('NSRightExpression',g.add('NSSelfExpression',[('NSExpressionType',0,1)])),ref('NSPredicateOperator',g.add('NSEqualityPredicateOperator',[('NSOperatorType',0,4),('NSModifier',0,0),('NSOptions',0,0)]))]))
    g=Graph(); save(g, 'NSSwitch',g.view('NSSwitch',[ref('NSControlContents',g.add('NSNumber',[('NS.intval',0,1)])),('NSEnabled',4,False)]))
    g=Graph(); save(g, 'WebPreferences',g.add('WebPreferences',[ref('Identifier',g.text('Synthetic')),ref('Values',g.dictionary({}))]))
    g=Graph(); save(g, 'WebView',g.view('WebView',[ref('FrameName',g.text('SyntheticFrame')),('UseBackForwardList',5,True)]))
    g=Graph(); save(g, 'CIMaskToAlpha',g.add('CIMaskToAlpha',[]))
    g=Graph(); save(g, 'NSTextTab',g.add('NSTextTab',[('Type',0,1),('Location',6,42.0)]))
    (output/'classes.plist').write_bytes(plistlib.dumps(cases))
    # View/guide cycles, constraints, priorities and a hidden child are intentional.
    g=Graph(); owner=g.view(); guide=g.add('NSLayoutGuide',[ref('NSLayoutGuideIdentifier',g.text('owned')),('NSLayoutGuideLockedToOwningView',5,True)])
    child=g.view(values=[ref('NSSuperview',owner)],frame='{{7, 9}, {40, 20}}')
    g.nodes[child][1][:]=[v for v in g.nodes[child][1] if v[0]!='NSvFlags']+[('NSvFlags',2,-2147483392)]
    constraint=g.add('NSLayoutConstraint',[ref('NSFirstItem',guide),('NSFirstAttribute',0,7),('NSConstant',7,80.0)])
    g.nodes[owner][1].extend([ref('NSSubviews',g.array([child])),ref('NSViewLayoutGuides',g.array([guide])),ref('NSViewConstraints',g.array([constraint])),('NSDoNotTranslateAutoresizingMask',5,True),ref('NSHuggingPriority',g.text('{251, 252}')),ref('NSAntiCompressionPriority',g.text('{751, 752}')),ref('NSReuseIdentifierKey',g.text('owned-view'))])
    g.write(output,'view-state',owner)
    # Replacement must be published before a child follows its parent reference.
    g=Graph(); owner=g.view('NSCustomView',[ref('NSClassName',g.text('NSView'))])
    child=g.view(values=[ref('NSSuperview',owner)])
    g.nodes[owner][1].extend([ref('NSSubviews',g.array([child])),('NSDoNotTranslateAutoresizingMask',5,True),ref('NSReuseIdentifierKey',g.text('replacement'))])
    g.write(output,'custom-view-cycle',owner)
    g=Graph(); child=g.view(frame='{{0, 0}, {20, 10}}'); container=g.view('NSStackViewContainer',[ref('NSStackViewContainerNonDroppedViews',g.array([child]))]); stack=g.view('NSStackView',[ref('NSStackViewBeginningContainer',container),('NSStackViewAlignment',0,5),('NSStackViewSpacing',7,13.0),('NSStackViewOrientation',0,1),('NSStackViewdistribution',0,1),('NSStackViewEdgeInsets.top',7,3.0),('NSStackViewEdgeInsets.left',7,4.0),('NSStackViewEdgeInsets.bottom',7,5.0),('NSStackViewEdgeInsets.right',7,6.0)])
    g.nodes[container][1].append(ref('NSStackViewContainerStackView',stack)); g.write(output,'stack-state',stack)
    g=Graph(); cell=g.add('NSButtonCell',[ref('NSContents',g.text('Synthetic'))]); control=g.view('NSButton',[ref('NSCell',cell),('NSEnabled',4,False),('NSControlSize',0,1),('NSControlTextAlignment',0,2),('NSControlSendActionMask',0,0)]);g.write(output,'control-state',control)
    g=Graph(); menu=g.add('NSMenuItem',[ref('NSTitle',g.text('Synthetic')),ref('NSKeyEquiv',g.text('')),('NSIsDisabled',5,True),('NSIsHidden',5,True),('NSIsAlternate',5,True),('NSState',0,1),('NSIndent',0,2)]);g.write(output,'menu-state',menu)
    g=Graph();table=g.view('NSTableView',[ref('NSTableColumns',g.array([])),('NSRowHeight',7,23.0),('NSIntercellSpacingWidth',7,5.0),('NSIntercellSpacingHeight',7,6.0),('NSTableViewStyle',0,3)]);g.write(output,'table-state',table)
    g=Graph();g.write(output,'outline-empty',g.view('NSOutlineView',[ref('NSTableColumns',g.array([])),('NSOutlineViewIndentationPerLevelKey',7,17.0)]))
    # Hidden columns retain public indexes and widths, but consume no display space.
    g=Graph()
    hidden=g.add('NSTableColumn',[ref('NSIdentifier',g.text('hidden')),('NSWidth',7,70.0),('NSMinWidth',7,10.0),('NSMaxWidth',7,200.0),('NSHidden',5,True)])
    visible=g.add('NSTableColumn',[ref('NSIdentifier',g.text('visible')),('NSWidth',7,90.0),('NSMinWidth',7,10.0),('NSMaxWidth',7,200.0)])
    header=g.view('NSTableHeaderView')
    table=g.view('NSTableView',[ref('NSTableColumns',g.array([hidden,visible])),ref('NSHeaderView',header),('NSIntercellSpacingWidth',7,3.0)])
    g.nodes[header][1].append(ref('NSTableView',table));g.write(output,'table-hidden',table)
    g=Graph();g.write(output,'path-state',g.view('NSPathControl',[ref('NSCell',g.add('NSPathCell',[('NSContents',9,None)]))]))
    g=Graph();g.write(output,'aux-empty',g.add('NSNibAuxiliaryActionConnector',[]))


if __name__ == '__main__': fixtures(Path(sys.argv[1]))
