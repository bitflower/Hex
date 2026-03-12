import ComposableArchitecture
import HexCore
import SwiftUI

struct IOSSettingsView: View {
  @Bindable var store: StoreOf<IOSSettingsFeature>

  var body: some View {
    NavigationStack {
      Form {
        Section("Transcription Model") {
          modelSection
        }

        Section("Language") {
          languageSection
        }

        Section("Sound Effects") {
          soundSection
        }

        Section("History") {
          Toggle("Save Transcription History", isOn: Binding(
            get: { store.hexSettings.saveTranscriptionHistory },
            set: { _ in store.send(.toggleHistory) }
          ))
        }

        Section {
          shortcutGuide(
            name: "Hex Save Note",
            imageName: "shortcut-save-note",
            steps: [
              "Add a **Create Note** action",
              "Set the body to **Shortcut Input**",
              "Set the folder to your target folder (e.g., \"Stream of Thought\")"
            ]
          )
          shortcutGuide(
            name: "Hex Append Note",
            imageName: "shortcut-append-note",
            steps: [
              "Add **Find Notes** — set folder to your target folder, sort by **Date Modified** (newest first), limit to **10**",
              "Add **Choose from List** — set input to the found notes",
              "Add **Append to Note** — set text to **Shortcut Input**, set note to **Chosen Item**"
            ]
          )

          Button {
            if let url = URL(string: "shortcuts://") {
              UIApplication.shared.open(url)
            }
          } label: {
            Label("Open Shortcuts App", systemImage: "arrow.up.forward.app")
          }
        } header: {
          Text("Apple Notes")
        } footer: {
          Text("These shortcuts let Hex create and append notes directly without interaction.")
        }

        Section("About") {
          LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
          LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—")
        }
      }
      .navigationTitle("Settings")
      .task { store.send(.task) }
    }
  }

  // MARK: - Model Section

  @ViewBuilder
  private var modelSection: some View {
    let models: [CuratedModelInfo] = Array(store.modelDownload.curatedModels)
    let selected = store.hexSettings.selectedModel

    ForEach(models) { model in
      modelRow(model: model, isSelected: selected == model.internalName)
    }

    downloadSection
  }

  private func modelRow(model: CuratedModelInfo, isSelected: Bool) -> some View {
    Button {
      store.send(.modelDownload(.selectModel(model.internalName)))
    } label: {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 4) {
            Text(model.displayName)
              .foregroundStyle(.primary)
            if let badge = model.badge {
              Text(badge)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.orange)
            }
          }
          HStack(spacing: 4) {
            Text(model.size)
            Text("·")
            Text(model.storageSize)
          }
          .font(.caption)
          .foregroundStyle(.secondary)
        }

        Spacer()

        if model.isDownloaded {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
            .font(.caption)
        }

        if isSelected {
          Image(systemName: "checkmark")
            .foregroundStyle(Color.accentColor)
            .fontWeight(.semibold)
        }
      }
    }
  }

  @ViewBuilder
  private var downloadSection: some View {
    let md = store.modelDownload
    if !md.selectedModelIsDownloaded {
      if md.isDownloading {
        HStack {
          ProgressView(value: md.downloadProgress)
          Button("Cancel") {
            store.send(.modelDownload(.cancelDownload))
          }
          .buttonStyle(.borderless)
          .foregroundStyle(.red)
        }
      } else {
        Button {
          store.send(.modelDownload(.downloadSelectedModel))
        } label: {
          Label("Download Selected Model", systemImage: "arrow.down.circle")
        }
      }
    }

    if let error = md.downloadError {
      Text(error)
        .font(.caption)
        .foregroundStyle(.red)
    }
  }

  // MARK: - Language

  @ViewBuilder
  private var languageSection: some View {
    Picker("Output Language", selection: Binding(
      get: { store.hexSettings.outputLanguage },
      set: { store.send(.setLanguage($0)) }
    )) {
      Text("Auto").tag(nil as String?)
      ForEach(Self.loadLanguages()) { language in
        Text(language.name).tag(language.code as String?)
      }
    }
  }

  // MARK: - Sound

  @ViewBuilder
  private var soundSection: some View {
    Toggle("Sound Effects", isOn: Binding(
      get: { store.hexSettings.soundEffectsEnabled },
      set: { _ in store.send(.toggleSoundEffects) }
    ))

    if store.hexSettings.soundEffectsEnabled {
      HStack {
        Image(systemName: "speaker.fill")
          .foregroundStyle(.secondary)
        Slider(
          value: Binding(
            get: { store.hexSettings.soundEffectsVolume },
            set: { store.send(.setSoundVolume($0)) }
          ),
          in: 0...HexSettings.baseSoundEffectsVolume
        )
        Image(systemName: "speaker.wave.3.fill")
          .foregroundStyle(.secondary)
      }
    }
  }

  // MARK: - Shortcut Guide

  @State private var expandedShortcut: String?

  @ViewBuilder
  private func shortcutGuide(name: String, imageName: String, steps: [String]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Button {
        withAnimation {
          expandedShortcut = expandedShortcut == name ? nil : name
        }
      } label: {
        HStack {
          Label(name, systemImage: "command.square")
            .font(.subheadline.weight(.semibold))
          Spacer()
          Image(systemName: expandedShortcut == name ? "chevron.up" : "chevron.down")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .tint(.primary)

      if expandedShortcut == name {
        VStack(alignment: .leading, spacing: 4) {
          ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
            HStack(alignment: .top, spacing: 6) {
              Text("\(index + 1).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16, alignment: .trailing)
              Text(LocalizedStringKey(step))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }

        if let uiImage = UIImage(named: imageName) ?? loadResourceImage(named: imageName) {
          Image(uiImage: uiImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
      }
    }
    .padding(.vertical, 4)
  }

  private func loadResourceImage(named name: String) -> UIImage? {
    if let url = Bundle.main.url(forResource: name, withExtension: "png"),
       let data = try? Data(contentsOf: url) {
      return UIImage(data: data)
    }
    if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Images"),
       let data = try? Data(contentsOf: url) {
      return UIImage(data: data)
    }
    return nil
  }

  // MARK: - Helpers

  static func loadLanguages() -> [Language] {
    guard let url = Bundle.main.url(forResource: "languages", withExtension: "json") ??
      Bundle.main.url(forResource: "languages", withExtension: "json", subdirectory: "Data"),
      let data = try? Data(contentsOf: url),
      let list = try? JSONDecoder().decode(LanguageList.self, from: data)
    else { return [] }
    return list.languages
  }
}
