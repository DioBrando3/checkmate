import AppKit
import SwiftUI
import QuartzCore
import CheckmateCore
struct Metrics {
    static let playbackLineHeight:CGFloat=2,turnIndicatorSize:CGFloat=12,turnIndicatorOutline:CGFloat=1
    static let core:CGFloat=780,minimum:CGFloat=600,minimumFitted:CGFloat=320,left:CGFloat=216,right:CGFloat=320,header:CGFloat=52
    static let mascotSize:CGFloat=72,settingsDetailMinimum:CGFloat=480,settingsFormMinimumHeight:CGFloat=380
    static let button:CGFloat=32,padding:CGFloat=16,smallGap:CGFloat=8,sectionGap:CGFloat=20,boardMargin:CGFloat=20,coordinateSize:CGFloat=11
    static let animation=0.7,frameInterval=1.0/60,settingsWidth:CGFloat=780,settingsHeight:CGFloat=560,settingsSidebar:CGFloat=190
}
func symbolButton(_ symbol:String,_ label:String,_ target:AnyObject,_ action:Selector)->NSButton {
    let b=NSButton(image:NSImage(systemSymbolName:symbol,accessibilityDescription:label)!,target:target,action:action)
    b.bezelStyle = .toolbar;b.imagePosition = .imageOnly;b.toolTip=ChineseText.text(label);b.setAccessibilityLabel(ChineseText.text(label));return b
}
final class ChineseLabel:NSTextField {
    override var stringValue:String {get{super.stringValue} set{super.stringValue=ChineseText.text(newValue)}}
}
final class ChineseAlert:NSAlert {
    override var messageText:String {get{super.messageText} set{super.messageText=ChineseText.text(newValue)}}
    override var informativeText:String {get{super.informativeText} set{super.informativeText=ChineseText.text(newValue)}}
}
func textLabel(_ text:String,_ size:CGFloat=13,_ weight:NSFont.Weight = .regular)->NSTextField {let l=ChineseLabel(labelWithString:ChineseText.text(text));l.font = .systemFont(ofSize:size,weight:weight);l.lineBreakMode = .byWordWrapping;return l}
final class BackgroundView:NSView {override func draw(_ rect:NSRect){NativeColors.windowBackground.setFill();rect.fill()};override func viewDidChangeEffectiveAppearance(){super.viewDidChangeEffectiveAppearance();needsDisplay=true}}
struct NativeIcon:View {let symbol:String,label:String,action:()->Void;var body:some View {Button(action:action){Image(systemName:symbol)}.help(ChineseText.text(label)).accessibilityLabel(ChineseText.text(label)).buttonStyle(.bordered)}}
