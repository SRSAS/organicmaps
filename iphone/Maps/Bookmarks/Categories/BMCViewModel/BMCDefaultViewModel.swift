protocol BMCView: AnyObject {
  func update(sections: [BMCSection])
  func delete(at indexPaths: [IndexPath])
  func insert(at indexPaths: [IndexPath])
  func conversionFinished(success: Bool)
}

final class BMCDefaultViewModel: NSObject {
  private let manager = BookmarksManager.shared()

  weak var view: BMCView?

  private var sections: [BMCSection] = []
  private var categories: [BookmarkGroup] = []
  private var actions: [BMCAction] = []
  private var notifications: [BMCNotification] = []

  private(set) var isPendingPermission = false
  private var isAuthenticated = false
  private var filesPrepared = false

  let minCategoryNameLength: UInt = 0
  let maxCategoryNameLength: UInt = 60

  override init() {
    super.init()
    reloadData()
  }

  private func setCategories() {
    categories = manager.sortedUserCategories()
  }

  private func setActions() {
    actions = [.create]
    actions.append(.import)
    if !manager.areAllCategoriesEmpty() {
      actions.append(.exportAll)
    }
  }

  private func setNotifications() {
    notifications = [.load]
  }

  func reloadData() {
    sections = []

    if manager.areBookmarksLoaded() {
      sections.append(.categories)
      setCategories()

      sections.append(.actions)
      setActions()
    } else {
      sections.append(.notifications)
      setNotifications()
    }
    view?.update(sections: [])
  }
}

extension BMCDefaultViewModel {
  func numberOfSections() -> Int {
    return sections.count
  }

  func sectionType(section: Int) -> BMCSection {
    return sections[section]
  }

  func sectionIndex(section: BMCSection) -> Int {
    return sections.firstIndex(of: section)!
  }

  func numberOfRows(section: Int) -> Int {
    return numberOfRows(section: sectionType(section: section))
  }

  func numberOfRows(section: BMCSection) -> Int {
    switch section {
    case .categories: return categories.count
    case .actions: return actions.count
    case .notifications: return notifications.count
    }
  }

  func category(at index: Int) -> BookmarkGroup {
    return categories[index]
  }

  func action(at index: Int) -> BMCAction {
    return actions[index]
  }

  func notification(at index: Int) -> BMCNotification {
    return notifications[index]
  }

  func areAllCategoriesHidden() -> Bool {
    var result = true
    categories.forEach { if $0.isVisible { result = false } }
    return result
  }

  func updateAllCategoriesVisibility(isShowAll: Bool) {
    manager.setUserCategoriesVisible(isShowAll)
  }

  func addCategory(name: String) {
    guard let section = sections.firstIndex(of: .categories) else {
      assertionFailure()
      return
    }

    categories.append(manager.category(withId: manager.createCategory(withName: name)))
    view?.insert(at: [IndexPath(row: categories.count - 1, section: section)])
  }

  func deleteCategory(at index: Int) {
    guard let section = sections.firstIndex(of: .categories) else {
      assertionFailure()
      return
    }

    let category = categories[index]
    categories.remove(at: index)
    view?.delete(at: [IndexPath(row: index, section: section)])
    manager.deleteCategory(category.categoryId)
  }

  func checkCategory(name: String) -> Bool {
    return manager.checkCategoryName(name)
  }

  func shareCategoryFile(at index: Int, fileType: KmlFileType, handler: @escaping SharingResultCompletionHandler) {
    let category = categories[index]
    manager.shareCategory(category.categoryId, fileType: fileType, completion: handler)
  }

  func shareAllCategories(handler: @escaping SharingResultCompletionHandler) {
    manager.shareAllCategories(completion: handler)
  }

  func importCategories(from urls: [URL]) {
    // TODO: Refactor this call when the multiple files parsing support will be added to the bookmark_manager.
    urls.forEach(manager.loadBookmarkFile(_:))
  }

  func finishShareCategory() {
    manager.finishShareCategory()
  }

  func addToObserverList() {
    manager.add(self)
  }

  func removeFromObserverList() {
    manager.remove(self)
  }

  func setNotificationsEnabled(_ enabled: Bool) {
    manager.setNotificationsEnabled(enabled)
  }

  func areNotificationsEnabled() -> Bool {
    return manager.areNotificationsEnabled()
  }
}

extension BMCDefaultViewModel: BookmarksObserver {

  func onBookmarksLoadFinished() {
    reloadData()
  }

  func onBookmarksCategoryDeleted(_ groupId: MWMMarkGroupID) {
    reloadData()
  }

  func onBookmarkDeleted(_: MWMMarkID) {
    reloadData()
  }
}
