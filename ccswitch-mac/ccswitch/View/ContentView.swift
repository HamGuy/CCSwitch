//
//  ContentView.swift
//  ccswitch
//
//  Created by HamGuy on 2025/7/22.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "c.circle.fill")
                    .imageScale(.large)
                    .foregroundColor(.accentColor)
                Text("CC Switch")
                    .font(.headline)
                Spacer()
            }
            .padding(.bottom, 8)
            
            Text(LocalizedStringKey("Current Configuration:"))
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(LocalizedStringKey("Default"))
                .font(.body)
                .padding(.bottom, 8)
            
            Divider()
            
            Text(LocalizedStringKey("Preset Configurations"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 4)
            
            ConfigButton(name: String(localized: "GAC Code"), isActive: false)
            ConfigButton(name: String(localized: "Anyrouter"), isActive: false)
            ConfigButton(name: String(localized:"Kimi"), isActive: false)
            
            Divider()
            
            Button(action: {
                // Add new configuration action
            }) {
                Label(LocalizedStringKey("Add Configuration"), systemImage: "plus")
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)
            
            Button(action: {
                // Reset to default action
            }) {
                Label(LocalizedStringKey("Reset to Default"), systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)
            
            Divider()
            
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Label(LocalizedStringKey("Quit"), systemImage: "power")
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)
        }
        .padding()
        .frame(width: 280)
    }
}

struct ConfigButton: View {
    let name: String
    let isActive: Bool
    
    var body: some View {
        Button(action: {
            // Switch to this configuration
        }) {
            HStack {
                Text(name)
                Spacer()
                if isActive {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}
