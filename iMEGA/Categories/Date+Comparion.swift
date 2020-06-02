//
//  Date+Comparion.swift
//  MEGA
//
//  Created by Jun Meng on 31/5/20.
//  Copyright © 2020 MEGA. All rights reserved.
//

import Foundation

extension Date {

    typealias NumberOfDays = Int

    /// Will return an count of calendar days from `self` to a given *future* date.
    /// Discussion: This function is used to calculate distance of calendar days to a *future* date which means
    /// at least `futureDate` is later than or equal to current instance, so that the `numberOfDays` will be a positive number,
    /// or else, nil will be return.
    /// - Parameters:
    ///   - futureDate: A date in the future on which this distance of days will be calculated based.
    ///   - calendar: A calendar object on which the calendar days to be based on.
    /// - Returns:
    func dayDistance(toFutureDate futureDate: Date, on calendar: Calendar) -> NumberOfDays? {
        assert(futureDate >= self)
        guard futureDate >= self else { return nil }
        return calendar.dateComponents([.day], from: self, to: futureDate).day
    }

    /// Will return an count of calendar days from `self` to a given *past* date.
    /// Discussion: This function is used to calculate distance of calendar days to a *past* date which means
    /// at least `pastDate` is earlier than or equal to current instance, so that the `numberOfDays` will be a positive number,
    /// or else, nil will be return.
    /// - Parameters:
    ///   - pastDate: A date in the future on which this distance of days will be calculated based.
    ///   - calendar: A calendar object on which the calendar days to be based on.
    /// - Returns:
    func dayDistance(toPastDate pastDate: Date, on calendar: Calendar) -> NumberOfDays? {
        guard pastDate <= self else { return nil }
        return calendar.dateComponents([.day], from: self, to: pastDate).day.map(abs)
    }
}

extension Date {

    /// Indicates the invoker on the given calendar is *Today*.
    /// - Parameter calendar: The calendar which is used to consult *Today* information from.
    /// - Returns: True if invoker is today on calendar, else false.
    func isToday(on calendar: Calendar) -> Bool {
        return calendar.isDateInToday(self)
    }

    /// Indicates the invoker on the given calendar is *Tomorrow*.
    /// - Parameter calendar: The calendar which is used to consult  *Tomorrow* information from.
    /// - Returns: True if invoker is tomorrow on calendar, else false.
    func isTomorrow(on calendar: Calendar) -> Bool {
        return calendar.isDateInTomorrow(self)
    }
}
