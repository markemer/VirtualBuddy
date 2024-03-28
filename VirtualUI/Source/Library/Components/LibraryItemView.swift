//
//  LibraryItemView.swift
//  VirtualUI
//
//  Created by Guilherme Rambo on 21/07/22.
//

import SwiftUI
import VirtualCore

struct VirtualMachineButtonStyle: ButtonStyle {

    let vm: VBVirtualMachine

    func makeBody(configuration: Configuration) -> some View {
        LibraryItemView(
            vm: vm,
            name: vm.name,
            isPressed: configuration.isPressed
        )
    }

}

@MainActor
struct LibraryItemView: View {

    @EnvironmentObject var library: VMLibraryController

    @State var vm: VBVirtualMachine
    @State var name: String
    var isPressed = false

    @State private var thumbnail = Image(nsImage: .thumbnailPlaceholder)

    var nameFieldFocus = BoolSubject()

    private var isVMBooted: Bool { library.bootedMachineIdentifiers.contains(vm.id) }

    var body: some View {
        VStack(spacing: 12) {
            thumbnailView
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .shadow(color: Color.black.opacity(0.4), radius: 4)

            EphemeralTextField($name, alignment: .leading, setFocus: nameFieldFocus) { name in
                Text(name)
            } editableContent: { name in
                TextField("VM Name", text: name)
            } validate: { name in
                do {
                    try library.validateNewName(name, for: vm)
                    return true
                } catch {
                    return false
                }
            }
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .disabled(isVMBooted)
        }
        .padding([.leading, .trailing, .top], 8)
        .padding(.bottom, 12)
        .background(Material.thin, in: backgroundShape)
        .background {
            thumbnail
                .resizable()
                .blur(radius: 22)
                .opacity(isPressed ? 0.1 : 0.4)
        }
        .clipShape(backgroundShape)
        .shadow(color: Color.black.opacity(0.14), radius: 12)
        .shadow(color: Color.black.opacity(0.56), radius: 1)
        .scaleEffect(isPressed ? 0.96 : 1)
        .onAppear { refreshThumbnail() }
        .onReceive(vm.didInvalidateThumbnail) { refreshThumbnail() }
        .contextMenu { contextMenuItems }
        .onChange(of: name) { [name] newName in
            guard newName != name else { return }

            do {
                try library.rename(vm, to: newName)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
        .onChange(of: vm.name) { [vm] updatedName in
            guard updatedName != vm.name else { return }
            self.name = updatedName
        }
    }

    private func refreshThumbnail() {
        if let nsImage = vm.thumbnailImage() {
            thumbnail = Image(nsImage: nsImage)
        } else {
            thumbnail = Image(nsImage: .thumbnailPlaceholder)
        }
    }

    private var backgroundShape: some InsettableShape {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
    }

    @ViewBuilder
    private var thumbnailView: some View {
        thumbnail
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .bottom)
            .clipped()
            .aspectRatio(16/9, contentMode: .fit)
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        Button {
            NSWorkspace.shared.selectFile(vm.bundleURL.path, inFileViewerRootedAtPath: vm.bundleURL.deletingLastPathComponent().path)
        } label: {
            Label("Show in Finder", systemImage: "folder")
        }

        Divider()

        Button {
            duplicate()
        } label: {
            Text("Duplicate")
        }

        Button {
            nameFieldFocus.send(true)
        } label: {
            Text("Rename")
        }
        .disabled(isVMBooted)

        #if DEBUG
        Button {
            NSWorkspace.shared.open(vm.metadataDirectoryURL)
        } label: {
            Text("Open Data Folder…")
        }
        #endif

        Divider()

        Button {
            library.performMoveToTrash(for: vm)
        } label: {
            Text("Move to Trash")
        }
        .disabled(isVMBooted)
    }

    private func duplicate() {
        Task {
            do {
                try library.duplicate(vm)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }

}

extension VMLibraryController {
    func performMoveToTrash(for vm: VBVirtualMachine) {
        Task {
            do {
                try await moveToTrash(vm)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }
}
