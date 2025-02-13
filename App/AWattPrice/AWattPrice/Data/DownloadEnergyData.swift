//
//  DownloadEnergyData.swift
//  AwattarApp
//
//  Created by Léon Becker on 07.09.20.
//

import Foundation
import Network
import SwiftUI

/// A single energy price data point. It has a start and end time. Throughout this time range a certain marketprice/energy price applies. This price is also held in this energy price data point.
struct EnergyPricePoint: Hashable, Codable {
    var startTimestamp: Int
    var endTimestamp: Int
    var marketprice: Double

    enum CodingKeys: String, CodingKey {
        case startTimestamp = "start_timestamp"
        case endTimestamp = "end_timestamp"
        case marketprice
    }
}

/// A object containing all EnergyPricePoint's. It also holds two values for the smallest and the largest energy price of all containing energy data points.
struct EnergyData: Codable {
    var prices: [EnergyPricePoint]
    var minPrice: Double = 0
    var maxPrice: Double = 0

    enum CodingKeys: String, CodingKey {
        case prices
    }
}

/// A single aWATTar Profile with a name and an name of the image representing this profile.
struct Profile: Hashable {
    var name: String
    var imageName: String
}

/// Defines all profiles that exist.
struct ProfilesData {
    var profiles = [
        Profile(name: "HOURLY", imageName: "HourlyProfilePicture"),
    ]
}

/// Object responsible for downloading the current energy prices from the backend,
/// decoding this data and providing it to all views which need it. It also includes data for the different
/// profiles/tariffs of aWATTar which don't need to be downloaded.
class AwattarData: ObservableObject {
    @Published var currentlyNoData = false // Set to true if the price data in the downloaded data is empty.
    @Published var currentlyUpdatingData = false
    @Published var dateDataLastUpdated: Date?
    @Published var dataRetrievalError = false
    @Published var energyData: EnergyData?
    @Published var profilesData = ProfilesData()

    func download(forRegion regionIdentifier: Int16, networkManager: NetworkManager) {
        currentlyUpdatingData = true
        dataRetrievalError = false

        var downloadURL = ""

        if regionIdentifier == 1 {
            downloadURL = GlobalAppSettings.rootURLString + "/data/AT"
        } else {
            downloadURL = GlobalAppSettings.rootURLString + "/data/DE"
        }

        var energyRequest = URLRequest(
            url: URL(string: downloadURL)!,
            cachePolicy: URLRequest.CachePolicy.useProtocolCachePolicy
        )

        energyRequest.httpMethod = "GET"

        var dataComesFromCache = false
        if URLCache.shared.cachedResponse(for: energyRequest) != nil {
            dataComesFromCache = true
        }

        let beforeTime = Date()
        URLSession.shared.dataTask(with: energyRequest) { data, _, error in
            if let data = data {
                self.parseResponseData(data)
            } else {
                print("A data retrieval error occurred.")
                if error != nil {
                    DispatchQueue.main.async {
                        withAnimation {
                            self.dataRetrievalError = true
                        }
                    }
                }
            }

            DispatchQueue.main.async {
                if dataComesFromCache == true, networkManager.monitorer.currentPath.status == .unsatisfied {
                    self.dataRetrievalError = true
                }

                if self.dataRetrievalError == false {
                    self.dateDataLastUpdated = Date()
                }

                if Date().timeIntervalSince(beforeTime) < 0.6 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + (0.6 - Date().timeIntervalSince(beforeTime))) {
                        // If the data could be retrieved very fast (< 0.6s) than changes to text, ... could look very sudden.
                        // Thats why add a small delay to result in a 0.6s delay.
                        self.currentlyUpdatingData = false
                    }
                } else {
                    self.currentlyUpdatingData = false
                }
            }
        }.resume()
    }
}

extension AwattarData {
    // Parsing functions
    
    func parseResponseData(_ data: Data) {
        var decodedData = EnergyData(prices: [], minPrice: 0, maxPrice: 0)
        do {
            let jsonDecoder = JSONDecoder()
            decodedData = try jsonDecoder.decode(EnergyData.self, from: data)
            let currentHour = Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: Date()), minute: 0, second: 0, of: Date())!

            var usedPricesDecodedData = [EnergyPricePoint]()
            var minPrice: Double?
            var maxPrice: Double?

            for hourPoint in decodedData.prices {
                if Date(timeIntervalSince1970: TimeInterval(hourPoint.startTimestamp)) >= currentHour {
                    var marketprice: Double = (hourPoint.marketprice * 100).rounded() / 100 // Round to two decimal places

                    if marketprice.sign == .minus && marketprice == 0 {
                        marketprice = 0
                    }

                    usedPricesDecodedData.append(EnergyPricePoint(startTimestamp: hourPoint.startTimestamp, endTimestamp: hourPoint.endTimestamp, marketprice: marketprice))

                    if maxPrice == nil || marketprice > maxPrice! {
                        maxPrice = marketprice
                    }

                    if minPrice == nil {
                        if marketprice < 0 {
                            minPrice = marketprice
                        }
                    } else if marketprice < minPrice! {
                        minPrice = marketprice
                    }
                }
            }

            let currentEnergyData = EnergyData(prices: usedPricesDecodedData, minPrice: minPrice ?? 0, maxPrice: maxPrice ?? 0)

            DispatchQueue.main.async {
                if currentEnergyData.prices.isEmpty {
                    print("No prices can be shown, because either there are none or they are outdated.")
                    withAnimation {
                        self.currentlyNoData = true
                    }
                } else {
                    self.energyData = currentEnergyData
                }

                self.dataRetrievalError = false
            }
        } catch {
            print("Could not decode returned JSON data from server.")
            DispatchQueue.main.async {
                withAnimation {
                    self.dataRetrievalError = true
                }
            }
        }
    }
}

extension AwattarData {
    var minMaxTimeRange: ClosedRange<Date>?     {
        if energyData != nil {
            if !(energyData!.prices.count > 0) {
                return nil
            }
            let maxHourIndex = energyData!.prices.count - 1
    
            // Add one or subtract one to not overlap to the next or previouse day
            let min = Date(
                timeIntervalSince1970: TimeInterval(energyData!.prices[0].startTimestamp)
            )
            let max = Date(
                timeIntervalSince1970: TimeInterval(energyData!.prices[maxHourIndex].endTimestamp)
            )
    
            return min ... max
        }
        return nil
    }
}
