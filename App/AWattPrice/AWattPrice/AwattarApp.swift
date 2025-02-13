//
//  AwattarAppApp.swift
//  AwattarApp
//
//  Created by Léon Becker on 06.09.20.
//

import CoreData
import SwiftUI

/// Represents if AWattPrice has the permissions to send notifications.
class NotificationAccess: ObservableObject {
    @Published var access = false
}

/// An object which holds and loads a NSPersistentContainer to allow access to persistent stored data from Core Data.
class PersistenceManager {
    var persistentContainer: NSPersistentContainer {
        let container = NSPersistentContainer(name: "Model")

        container.loadPersistentStores(completionHandler: { _, error in
            if let error = error {
                fatalError("Couldn't load persistent container. \(error)")
            }
        })

        return container
    }
}

/// Entry point of the app
@main
struct AwattarApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var awattarData: AwattarData
    var crtNotifiSetting: CurrentNotificationSetting
    var currentSetting: CurrentSetting
    var notificationAccess: NotificationAccess
    var persistence = PersistenceManager()

    init() {
        awattarData = AwattarData()
        crtNotifiSetting = CurrentNotificationSetting(
            managedObjectContext: persistence.persistentContainer.viewContext
        )
        currentSetting = CurrentSetting(
            managedObjectContext: persistence.persistentContainer.viewContext
        )
        notificationAccess = NotificationAccess()
        
        appDelegate.crtNotifiSetting = crtNotifiSetting
        appDelegate.currentSetting = currentSetting
    }

    var body: some Scene {
        WindowGroup {
            // The managedObjectContext from PersistenceManager mustn't be parsed to the views directly as environment value because views will only access it indirectly through CurrentSetting.

            ContentView()
                .environmentObject(awattarData)
                .environmentObject(currentSetting)
                .environmentObject(crtNotifiSetting)
                .environmentObject(CheapestHourManager())
                .environmentObject(notificationAccess)
        }
    }
}
