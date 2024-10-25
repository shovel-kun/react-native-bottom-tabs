import Foundation
import SwiftUI
import React

/**
 Props that component accepts. SwiftUI view gets re-rendered when ObservableObject changes.
 */
class TabViewProps: ObservableObject {
  @Published var children: [UIView]?
  @Published var items: TabData?
  @Published var selectedPage: String?
  @Published var icons: [Int: UIImage] = [:]
  @Published var sidebarAdaptable: Bool?
  @Published var labeled: Bool?
  @Published var ignoresTopSafeArea: Bool?
  @Published var disablePageAnimations: Bool = false
  @Published var scrollEdgeAppearance: String?
  @Published var barTintColor: UIColor?
  @Published var translucent: Bool = true
  @Published var activeTintColor: UIColor?
  @Published var inactiveTintColor: UIColor?
  
  var selectedActiveTintColor: UIColor? {
    if let selectedPage = selectedPage,
       let tabData = items?.tabs.findByKey(selectedPage),
       let activeTintColor = tabData.activeTintColor {
      return RCTConvert.uiColor(activeTintColor)
    }
    
    return activeTintColor
  }
}

/**
 Helper used to render UIView inside of SwiftUI.
 */
struct RepresentableView: UIViewRepresentable {
  var view: UIView
  
  func makeUIView(context: Context) -> UIView {
    return view
  }
  
  func updateUIView(_ uiView: UIView, context: Context) {}
}

/**
 SwiftUI implementation of TabView used to render React Native views.
 */
struct TabViewImpl: View {
  @ObservedObject var props: TabViewProps
  var onSelect: (_ key: String) -> Void
  var onLongPress: (_ key: String) -> Void
  
  var body: some View {
    TabView(selection: $props.selectedPage) {
      ForEach(props.children?.indices ?? 0..<0, id: \.self) { index in
        let child = props.children?[safe: index] ?? UIView()
        let tabData = props.items?.tabs[safe: index]
        let icon = props.icons[index]
        
        RepresentableView(view: child)
          .ignoresTopSafeArea(
            props.ignoresTopSafeArea ?? false,
            frame: child.frame
          )
          .tabItem {
            TabItem(
              title: tabData?.title,
              icon: icon,
              sfSymbol: tabData?.sfSymbol,
              labeled: props.labeled
            )
          }
          .tag(tabData?.key)
          .tabBadge(tabData?.badge)
      }
    }
    .onTabItemLongPress({ index in
        if let key = props.items?.tabs[safe: index]?.key {
          onLongPress(key)
        }
    })
    .tintColor(props.selectedActiveTintColor)
    .getSidebarAdaptable(enabled: props.sidebarAdaptable ?? false)
    .configureAppearance(props: props)
    .onChange(of: props.selectedPage ?? "") { newValue in
      if (props.disablePageAnimations) {
        UIView.setAnimationsEnabled(false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          UIView.setAnimationsEnabled(true)
        }
      }
      
      onSelect(newValue)
    }
  }
}

private func configureAppearance(for appearanceType: String, appearance: UITabBarAppearance) -> UITabBarAppearance {
  switch appearanceType {
  case "opaque":
    appearance.configureWithOpaqueBackground()
  case "transparent":
    appearance.configureWithTransparentBackground()
  default:
    appearance.configureWithDefaultBackground()
  }
  
  return appearance
}

private func setTabBarItemColors(_ itemAppearance: UITabBarItemAppearance, inactiveColor: UIColor) {
  itemAppearance.normal.iconColor = inactiveColor
  itemAppearance.normal.titleTextAttributes = [.foregroundColor: inactiveColor]
}

private func configureAppearance(inactiveTint inactiveTintColor: UIColor?, appearance: UITabBarAppearance) -> UITabBarAppearance {
  // @see https://stackoverflow.com/a/71934882
  if let inactiveTintColor {
    setTabBarItemColors(appearance.stackedLayoutAppearance, inactiveColor: inactiveTintColor)
    setTabBarItemColors(appearance.inlineLayoutAppearance, inactiveColor: inactiveTintColor)
    setTabBarItemColors(appearance.compactInlineLayoutAppearance, inactiveColor: inactiveTintColor)
  }
  
  return appearance
}

private func updateTabBarAppearance(props: TabViewProps) {
  var appearance = UITabBarAppearance()
  appearance = configureAppearance(for: props.scrollEdgeAppearance ?? "", appearance: appearance)
  appearance = configureAppearance(
    inactiveTint: props.inactiveTintColor,
    appearance: appearance
  )
  
  if #available(iOS 15.0, *) {
    UITabBar.appearance().scrollEdgeAppearance = appearance
    
    if props.translucent == false {
      appearance.configureWithOpaqueBackground()
    }
    
    if props.barTintColor != nil {
      appearance.backgroundColor = props.barTintColor
    }
  } else {
    UITabBar.appearance().barTintColor = props.barTintColor
    UITabBar.appearance().isTranslucent = props.translucent
  }
  
  UITabBar.appearance().standardAppearance = appearance
}

struct TabItem: View {
  var title: String?
  var icon: UIImage?
  var sfSymbol: String?
  var labeled: Bool?
  
  var body: some View {
    if let icon {
      Image(uiImage: icon)
    } else if let sfSymbol, !sfSymbol.isEmpty {
      Image(systemName: sfSymbol)
    }
    if (labeled != false) {
      Text(title ?? "")
    }
  }
}

extension View {
  @ViewBuilder
  func getSidebarAdaptable(enabled: Bool) -> some View {
    if #available(iOS 18.0, macOS 15.0, tvOS 18.0, visionOS 2.0, *) {
      if (enabled) {
#if compiler(>=6.0)
        self.tabViewStyle(.sidebarAdaptable)
#endif
      } else {
        self
      }
    } else {
      self
    }
  }
  
  @ViewBuilder
  func tabBadge(_ data: String?) -> some View {
    if #available(iOS 15.0, macOS 15.0, visionOS 2.0, *) {
      if let data = data, !data.isEmpty {
        self.badge(data)
      } else {
        self
      }
    } else {
      self
    }
  }
  
  @ViewBuilder
  func ignoresTopSafeArea(
    _ flag: Bool,
    frame: CGRect
  ) -> some View {
    if flag {
      self
        .ignoresSafeArea(.container, edges: .all)
        .frame(idealWidth: frame.width, idealHeight: frame.height)
    } else {
      self
        .ignoresSafeArea(.container, edges: .horizontal)
        .ignoresSafeArea(.container, edges: .bottom)
        .frame(idealWidth: frame.width, idealHeight: frame.height)
    }
  }
  
  @ViewBuilder
  func configureAppearance(props: TabViewProps) -> some View {
    self
      .onAppear() {
        updateTabBarAppearance(props: props)
      }
      .onChange(of: props.barTintColor) { newValue in
        updateTabBarAppearance(props: props)
      }
      .onChange(of: props.scrollEdgeAppearance) { newValue in
        updateTabBarAppearance(props: props)
      }
      .onChange(of: props.translucent) { newValue in
        updateTabBarAppearance(props: props)
      }
      .onChange(of: props.inactiveTintColor) { newValue in
        updateTabBarAppearance(props: props)
      }
      .onChange(of: props.selectedActiveTintColor) { newValue in
        updateTabBarAppearance(props: props)
      }
  }
  
  @ViewBuilder
  func tintColor(_ color: UIColor?) -> some View {
    if let color {
      let color = Color(color)
      if #available(iOS 16.0, *) {
        self.tint(color)
      } else {
        self.accentColor(color)
      }
    } else {
      self
    }
  }
}
