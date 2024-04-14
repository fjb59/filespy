/**
 * Copyright (c) 2017 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import Cocoa

class ViewController: NSViewController {

  // MARK: - Outlets

  @IBOutlet weak var tableView: NSTableView!
  @IBOutlet weak var infoTextView: NSTextView!
  @IBOutlet weak var saveInfoButton: NSButton!
  @IBOutlet weak var moveUpButton: NSButton!

  // MARK: - Properties

  var filesList: [URL] = []
  var showInvisibles = false

  var selectedFolder: URL? {
    didSet {
      if let selectedFolder = selectedFolder {
        filesList = contentsOf(folder: selectedFolder)
        selectedItem = nil
        self.tableView.reloadData()
        self.tableView.scrollRowToVisible(0)
        moveUpButton.isEnabled = true
        view.window?.title = selectedFolder.path
      } else {
        moveUpButton.isEnabled = false
        view.window?.title = "File Spy"
      }
    }
  }

  var selectedItem: URL? {
    didSet {
      infoTextView.string = ""
      saveInfoButton.isEnabled = false

      guard let selectedUrl = selectedItem else {
        return
      }

      let infoString = infoAbout(url: selectedUrl)
      if !infoString.isEmpty {
        let formattedText = formatInfoText(infoString)
        infoTextView.textStorage?.setAttributedString(formattedText)
        saveInfoButton.isEnabled = true
      }
    }
  }

  // MARK: - View Lifecycle & error dialog utility

  override func viewWillAppear() {
    super.viewWillAppear()

    restoreCurrentSelections()
  }

  override func viewWillDisappear() {
    saveCurrentSelections()

    super.viewWillDisappear()
  }

  func showErrorDialogIn(window: NSWindow, title: String, message: String) {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.alertStyle = .critical
    alert.beginSheetModal(for: window, completionHandler: nil)
  }

}

// MARK: - Getting file or folder information

extension ViewController {

  func contentsOf(folder: URL) -> [URL] {
      // 1
       let fileManager = FileManager.default

       // 2
       do {
         // 3
           let contents = try fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
         //  let images = contents.filter{ $0.pathExtension == "jpg" }

         // 4
           let urls = contents.map { return folder.appendingPathComponent($0.path) }
         return urls
       } catch {
         // 5
         return []
       }
  }

  func infoAbout(url: URL) -> String {
      let fileManager = FileManager.default

        // 2
        do {
          // 3
          let attributes = try fileManager.attributesOfItem(atPath: url.path)
          var report: [String] = ["\(url.path)", ""]

          // 4
          for (key, value) in attributes {
            // ignore NSFileExtendedAttributes as it is a messy dictionary
            if key.rawValue == "NSFileExtendedAttributes" { continue }
            report.append("\(key.rawValue):\t \(value)")
          }
          // 5
          return report.joined(separator: "\n")
        } catch {
          // 6
          return "No information available for \(url.path)"
        }
  }

  func formatInfoText(_ text: String) -> NSAttributedString {
      let paragraphStyle = NSMutableParagraphStyle.default.mutableCopy() as? NSMutableParagraphStyle
    paragraphStyle?.minimumLineHeight = 24
    paragraphStyle?.alignment = .left
    paragraphStyle?.tabStops = [ NSTextTab(type: .leftTabStopType, location: 240) ]

    let textAttributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key.font: NSFont.systemFont(ofSize: 14),
        NSAttributedString.Key.paragraphStyle: paragraphStyle ?? NSParagraphStyle.default
    ]

    let formattedText = NSAttributedString(string: text, attributes: textAttributes)
    return formattedText
  }


}

// MARK: - Actions

extension ViewController {

  @IBAction func selectFolderClicked(_ sender: Any)
  {
      guard let window = view.window else {return}
      
      let Panel = NSOpenPanel()
      Panel.canChooseFiles=false
      Panel.canChooseDirectories=true
      Panel.allowsMultipleSelection=false
      
      
      Panel.beginSheetModal(for: window) { (result) in
          if result == NSApplication.ModalResponse.OK {
          // 4
          self.selectedFolder = Panel.urls[0]
              
        }
      }
  }

  @IBAction func toggleShowInvisibles(_ sender: NSButton) {
  }

  @IBAction func tableViewDoubleClicked(_ sender: Any) {
  }

  @IBAction func moveUpClicked(_ sender: Any) {
  }

  @IBAction func saveInfoClicked(_ sender: Any) {
  }

}

// MARK: - NSTableViewDataSource

extension ViewController: NSTableViewDataSource {

  func numberOfRows(in tableView: NSTableView) -> Int {
    return filesList.count
  }

}

// MARK: - NSTableViewDelegate

extension ViewController: NSTableViewDelegate {

  func tableView(_ tableView: NSTableView, viewFor
    tableColumn: NSTableColumn?, row: Int) -> NSView? {
      let item = filesList[row]
      let fileIcon = NSWorkspace.shared.icon(forFile: item.path)
      if let cell = tableView.makeView(withIdentifier:  NSUserInterfaceItemIdentifier(rawValue:"FileCell") , owner: nil)
            as? NSTableCellView {
          // 4
          cell.textField?.stringValue = item.lastPathComponent
          cell.imageView?.image = fileIcon
          return cell
        }

    return nil
  }

  func tableViewSelectionDidChange(_ notification: Notification) {
    if tableView.selectedRow < 0 {
      selectedItem = nil
      return
    }

    selectedItem = filesList[tableView.selectedRow]
  }

}

// MARK: - Save & Restore previous selection

extension ViewController {

  func saveCurrentSelections() {
    guard let dataFileUrl = urlForDataStorage() else { return }

    let parentForStorage = selectedFolder?.path ?? ""
    let fileForStorage = selectedItem?.path ?? ""
    let completeData = "\(parentForStorage)\n\(fileForStorage)\n"

    try? completeData.write(to: dataFileUrl, atomically: true, encoding: .utf8)
  }

  func restoreCurrentSelections() {
    guard let dataFileUrl = urlForDataStorage() else { return }

    do {
      let storedData = try String(contentsOf: dataFileUrl)
      let storedDataComponents = storedData.components(separatedBy: .newlines)
      if storedDataComponents.count >= 2 {
        if !storedDataComponents[0].isEmpty {
          selectedFolder = URL(fileURLWithPath: storedDataComponents[0])
          if !storedDataComponents[1].isEmpty {
            selectedItem = URL(fileURLWithPath: storedDataComponents[1])
            selectUrlInTable(selectedItem)
          }
        }
      }
    } catch {
      print(error)
    }
  }

  private func selectUrlInTable(_ url: URL?) {
    guard let url = url else {
      tableView.deselectAll(nil)
      return
    }

      if let rowNumber = filesList.firstIndex(of: url) {
      let indexSet = IndexSet(integer: rowNumber)
      DispatchQueue.main.async {
        self.tableView.selectRowIndexes(indexSet, byExtendingSelection: false)
      }
    }
  }
  
  private func urlForDataStorage() -> URL? {
    return nil
  }

}
