//
//  Menu.swift
//  lightningMenu
//
//  Created by zaru on 2020/03/28.
//  Copyright © 2020年 zaru. All rights reserved.
//

import Cocoa

class MenuView: NSView {
    var appMenu: NSMenu = NSMenu()
    var allMenuItems: [NSMenuItem] = []
    var filterdMenuItems: [NSMenuItem] = []
    var topLevelMenuNum: Int = 0
    var pid: pid_t!
    var triggerItem: String?

    init(pid: pid_t, triggerItem: String? = nil) {
        self.pid = pid
        self.triggerItem = triggerItem
        super.init(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        if triggerItem != nil {
            makeMenu()
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // 検索用フィールドからフォーカスを移すために必要なフラグ
    override var acceptsFirstResponder: Bool {
        return true
    }

    func increment(element: AXUIElement, menuItem: NSMenuItem) {
        allMenuItems.append(menuItem)
    }

    func filterMenuItem(keyword: String) {

        filterdMenuItems = []
        // 検索時は既存のトップレベルメニューを隠す、空なら表示する
        let hidden = keyword == "" ? false : true
        for index in 1...topLevelMenuNum {
            let item = appMenu.items[index]
            item.isHidden = hidden
        }

        let startHitIndex = topLevelMenuNum + 1

        for _ in startHitIndex..<appMenu.items.count {
            // remove した時に index が上に詰まっていくので削除対象のインデックスは常に同じ
            if appMenu.items.indices.contains(startHitIndex) {
                appMenu.removeItem(at: startHitIndex)
            }
        }

        for item in allMenuItems {
            if item.title.localizedCaseInsensitiveContains(keyword) {
                guard let copyItem = item.copy() as? NSMenuItem else { continue }
                appMenu.addItem(copyItem)
                filterdMenuItems.append(copyItem)
            }
        }
    }

    func reset() {
        allMenuItems = []
        topLevelMenuNum = 0
    }

    func makeMenu() {
        reset()

        let searchItem = SearchMenuItem()
        searchItem.setNextKeyView(view: self)
        appMenu.addItem(searchItem)

        let items = getMenuItems(pid)
        topLevelMenuNum = items.count
        buildAllMenu(items)

        if triggerItem == nil {
            appMenu.popUp(positioning: nil, at: NSPoint.zero, in: self)
        }
    }

    func getMenuItems(_ pid: pid_t) -> [AXUIElement] {
        let appRef = AXUIElementCreateApplication(pid)
        var menubar: CFTypeRef?
        AXUIElementCopyAttributeValue(appRef, kAXMenuBarAttribute as CFString, &menubar)
        // TODO: ここで強制キャストをせずに渡す方法が見つからなかった、もしあれば直したい
        // swiftlint:disable:next force_cast
        return getChildren(menubar as! AXUIElement)
    }

    func buildAllMenu(_ elements: [AXUIElement]) {
        for element in elements {
            var title = getTitle(element)
            if title == "Apple" {
                title = ""
            }

            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            appMenu.addItem(item)

            buildSubMenu(mainElement: element, mainMenuItesm: item, parent: title)
        }
    }

    func buildSubMenu(mainElement: AXUIElement, mainMenuItesm: NSMenuItem, parent: String) {
        let subMenu = NSMenu()
        mainMenuItesm.submenu = subMenu

        let subElements = getChildren(mainElement)
        for subElement in subElements {
            let subMenuItems = getChildren(subElement)
            buildSubMenuItems(subMenuItemsElements: subMenuItems, subMenu: subMenu, parent: parent)
        }
    }

    func buildSubMenuItems(subMenuItemsElements: [AXUIElement], subMenu: NSMenu, parent: String) {
        for element in subMenuItemsElements {
            let position = getAttribute(element: element, name: kAXPositionAttribute)
            let title = getTitle(element)

            if position == nil {
                continue
            }

            if title == "" {
                subMenu.addItem(NSMenuItem.separator())
            } else {
                if triggerItem == parent + "→" + title {
                    let error = AXUIElementPerformAction(element, kAXPressAction as CFString)
                    if error != AXError.success {
                        print("failed to lauch \(triggerItem), \(error)")
                    }
                    return
                }
                let subMenuItem = NSMenuItem(title: title, action: #selector(AppDelegate.pressMenu), keyEquivalent: "")
                subMenuItem.representedObject = [parent + "→" + title: element] as KeyValuePairs
                increment(element: element, menuItem: subMenuItem)
                subMenu.addItem(subMenuItem)

                let lastMenuItems = getChildren(element)
                if lastMenuItems.count > 0 {
                    buildLastMenu(subElement: lastMenuItems[0], subMenuItesm: subMenuItem, parent: parent + "→" + title)
                }
            }

        }
    }

    func buildLastMenu(subElement: AXUIElement, subMenuItesm: NSMenuItem, parent: String) {
        let lastMenu = NSMenu()
        subMenuItesm.submenu = lastMenu

        let lastElements = getChildren(subElement)
        for element in lastElements {
            let position = getAttribute(element: element, name: kAXPositionAttribute)
            let enabled = getEnabled(element)
            let title = getTitle(element)

            if position == nil {
                continue
            }

            if title == "" {
                lastMenu.addItem(NSMenuItem.separator())
            } else if enabled {
                if triggerItem == parent + "→" + title {
                    let error = AXUIElementPerformAction(element, kAXPressAction as CFString)
                    if error != AXError.success {
                        print("failed to lauch \(triggerItem), \(error)")
                    }
                    return
                }
                let lastMenuItem = NSMenuItem(title: title, action: #selector(AppDelegate.pressMenu), keyEquivalent: "")
                lastMenuItem.representedObject = [parent + "→" + title: element] as KeyValuePairs
                increment(element: element, menuItem: lastMenuItem)
                lastMenu.addItem(lastMenuItem)
            } else {
                let lastMenuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                lastMenu.addItem(lastMenuItem)
            }
        }
    }

    func getChildren(_ element: AXUIElement) -> [AXUIElement] {
        let children = getAttribute(element: element, name: kAXChildrenAttribute)
        if children == nil {
            return []
        }
        if let childrenElements = children as? [AXUIElement] {
            return childrenElements
        }
        return []
    }

    func getTitle(_ element: AXUIElement) -> String {
        let title = getAttribute(element: element, name: kAXTitleAttribute)
        if title != nil, let titleString = title as? String {
            return titleString
        }
        return ""
    }

    func getEnabled(_ element: AXUIElement) -> Bool {
        let enabled = getAttribute(element: element, name: kAXEnabledAttribute)
        if enabled != nil, let enabledBool = enabled as? Bool {
            return enabledBool
        }
        return false
    }

    func getAttribute(element: AXUIElement, name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, name as CFString, &value)
        return value
    }
}
