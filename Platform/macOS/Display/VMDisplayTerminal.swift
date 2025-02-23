//
// Copyright © 2022 osy. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Combine
import SwiftTerm
import SwiftUI

private let kVMDefaultResizeCmd = "stty cols $COLS rows $ROWS\\n"

protocol VMDisplayTerminal {
    func setupTerminal(_ terminalView: TerminalView, using config: UTMConfigurationTerminal, for window: NSWindow)
    func resizeCommand(for terminal: TerminalView, using config: UTMConfigurationTerminal) -> String
}

extension VMDisplayTerminal {
    func setupTerminal(_ terminalView: TerminalView, using config: UTMConfigurationTerminal, for window: NSWindow) {
        let fontSize = config.fontSize
        let fontName = config.font.rawValue
        if fontName != "" {
            let orig = terminalView.font
            let new = NSFont(name: fontName, size: CGFloat(fontSize)) ?? orig
            terminalView.font = new
        } else {
            let orig = terminalView.font
            let new = NSFont(descriptor: orig.fontDescriptor, size: CGFloat(fontSize)) ?? orig
            terminalView.font = new
        }
        if let consoleTextColor = config.foregroundColor,
           let textColor = Color(hexString: consoleTextColor),
           let consoleBackgroundColor = config.backgroundColor,
           let backgroundColor = Color(hexString: consoleBackgroundColor) {
            terminalView.nativeForegroundColor = NSColor(textColor)
            terminalView.nativeBackgroundColor = NSColor(backgroundColor)
        }
        terminalView.getTerminal().resize(cols: 80, rows: 24)
        let size = window.frameRect(forContentRect: terminalView.getOptimalFrameSize()).size
        let frame = CGRect(origin: window.frame.origin, size: size)
        window.minSize = size
        window.setFrame(frame, display: false, animate: true)
    }
    
    func resizeCommand(for terminalView: TerminalView, using config: UTMConfigurationTerminal) -> String {
        let cols = terminalView.getTerminal().cols
        let rows = terminalView.getTerminal().rows
        let template = config.resizeCommand ?? kVMDefaultResizeCmd
        let cmd = template
            .replacingOccurrences(of: "$COLS", with: String(cols))
            .replacingOccurrences(of: "$ROWS", with: String(rows))
            .replacingOccurrences(of: "\\n", with: "\n")
        return cmd
    }
}
