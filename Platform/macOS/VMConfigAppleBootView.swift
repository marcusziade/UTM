//
// Copyright © 2021 osy. All rights reserved.
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

import Virtualization
import SwiftUI

@available(macOS 11, *)
struct VMConfigAppleBootView: View {
    private enum BootloaderSelection: Int, Identifiable {
        var id: Int {
            self.rawValue
        }
        case kernel
        case ramdisk
        case ipsw
        case unsupported
    }
    
    @Binding var config: UTMAppleConfigurationSystem
    @EnvironmentObject private var data: UTMData
    @State private var operatingSystem: UTMAppleConfigurationBoot.OperatingSystem = .none
    @State private var alertBootloaderSelection: BootloaderSelection?
    @State private var importBootloaderSelection: BootloaderSelection?
    @State private var importFileShown: Bool = false
    
    private var currentOperatingSystem: UTMAppleConfigurationBoot.OperatingSystem {
        config.boot.operatingSystem
    }
    
    var body: some View {
        Form {
            VMConfigConstantPicker("Operating System", selection: $operatingSystem)
            Picker("Bootloader", selection: $config.boot.hasUefiBoot) {
                Text(operatingSystem.prettyValue).tag(false)
                if #available(macOS 13, *) {
                    Text("UEFI").tag(true)
                }
            }
            .onAppear {
                operatingSystem = currentOperatingSystem
            }
            .onChange(of: operatingSystem) { newValue in
                guard newValue != currentOperatingSystem else {
                    return
                }
                config.boot.hasUefiBoot = false
                if newValue == .linux {
                    if #available(macOS 13, *) {
                        config.boot.hasUefiBoot = true
                        config.boot.operatingSystem = .linux
                    } else {
                        alertBootloaderSelection = .kernel
                    }
                } else if newValue == .macOS {
                    if #available(macOS 12, *) {
                        alertBootloaderSelection = .ipsw
                    } else {
                        alertBootloaderSelection = .unsupported
                    }
                } else {
                    config.boot.operatingSystem = .none
                }
                // don't change display until AFTER file selected
                importBootloaderSelection = nil
                operatingSystem = currentOperatingSystem
            }.onChange(of: config.boot.hasUefiBoot) { newValue in
                if !newValue && operatingSystem == .linux {
                    alertBootloaderSelection = .kernel
                    operatingSystem = .none
                }
            }.alert(item: $alertBootloaderSelection) { selection in
                let okay = Alert.Button.default(Text("OK")) {
                    importBootloaderSelection = selection
                    importFileShown = true
                }
                switch selection {
                case .kernel:
                    return Alert(title: Text("Please select an uncompressed Linux kernel image."), dismissButton: okay)
                case .ipsw:
                    return Alert(title: Text("Please select a macOS recovery IPSW."), primaryButton: okay, secondaryButton: .cancel())
                case .unsupported:
                    return Alert(title: Text("This operating system is unsupported on your machine."))
                default:
                    return Alert(title: Text("Select a file."), dismissButton: okay)
                }
            }.fileImporter(isPresented: $importFileShown,
                           allowedContentTypes: [importBootloaderSelection == .ipsw ? .ipsw : .data],
                           onCompletion: selectImportedFile)

            if operatingSystem == .linux && !config.boot.hasUefiBoot {
                Section(header: Text("Linux Settings")) {
                    HStack {
                        TextField("Kernel Image", text: .constant(config.boot.linuxKernelURL?.lastPathComponent ?? ""))
                            .disabled(true)
                        Button("Browse…") {
                            importBootloaderSelection = .kernel
                            importFileShown = true
                        }
                    }
                    HStack {
                        TextField("Ramdisk (optional)", text: .constant(config.boot.linuxInitialRamdiskURL?.lastPathComponent ?? ""))
                            .disabled(true)
                        Button("Clear") {
                            config.boot.linuxInitialRamdiskURL = nil
                        }
                        Button("Browse…") {
                            importBootloaderSelection = .ramdisk
                            importFileShown = true
                        }
                    }
                    TextField("Boot arguments", text: $config.boot.linuxCommandLine.bound)
                }
            } else if #available(macOS 12, *), operatingSystem == .macOS {
                #if arch(arm64)
                Section(header: Text("macOS Settings")) {
                    HStack {
                        TextField("IPSW Install Image", text: .constant(config.boot.macRecoveryIpswURL?.lastPathComponent ?? ""))
                            .disabled(true)
                        Button("Clear") {
                            config.boot.macRecoveryIpswURL = nil
                        }
                        Button("Browse…") {
                            importBootloaderSelection = .ipsw
                            importFileShown = true
                        }
                    }
                }
                #endif
            }
        }.onAppear {
            operatingSystem = currentOperatingSystem
        }
    }
    
    private func selectImportedFile(result: Result<URL, Error>) {
        // reset operating system to old value
        guard let selection = importBootloaderSelection else {
            return
        }
        data.busyWorkAsync {
            let url = try result.get()
            try await Task { @MainActor in
                switch selection {
                case .ipsw:
                    if #available(macOS 12, *) {
                        #if arch(arm64)
                        let image = try await VZMacOSRestoreImage.image(from: url)
                        guard let model = image.mostFeaturefulSupportedConfiguration?.hardwareModel else {
                            throw NSLocalizedString("Your machine does not support running this IPSW.", comment: "VMConfigAppleBootView")
                        }
                        config.macPlatform = UTMAppleConfigurationMacPlatform(newHardware: model)
                        config.boot.operatingSystem = .macOS
                        config.boot.macRecoveryIpswURL = url
                        #endif
                    }
                case .kernel:
                    config.boot.operatingSystem = .linux
                    config.boot.linuxKernelURL = url
                case .ramdisk:
                    config.boot.linuxInitialRamdiskURL = url
                case .unsupported:
                    break
                }
                operatingSystem = currentOperatingSystem
            }.value
        }
    }
}

@available(macOS 12, *)
struct VMConfigAppleBootView_Previews: PreviewProvider {
    @State static private var config = UTMAppleConfigurationSystem()
    
    static var previews: some View {
        VMConfigAppleBootView(config: $config)
    }
}
