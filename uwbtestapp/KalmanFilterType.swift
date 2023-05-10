//
//  KalmanFilterType.swift
//  KalmanFilter
//
//  Created by Oleksii on 18/08/16.
//  Copyright © 2016 Oleksii Dykan. All rights reserved.
//
import Foundation

public protocol KalmanInput {
    var transposed: Self { get }
    var inversed: Self { get }
    var additionToUnit: Self { get }
    
    static func + (lhs: Self, rhs: Self) -> Self
    static func - (lhs: Self, rhs: Self) -> Self
    static func * (lhs: Self, rhs: Self) -> Self
}

public protocol KalmanFilterType {
    associatedtype Input: KalmanInput
    
    var stateEstimatePrior: Input { get }
    var errorCovariancePrior: Input { get }
    
    func predict(stateTransitionModel: Input, controlInputModel: Input, controlVector: Input, covarianceOfProcessNoise: Input) -> Self
    func update(measurement: Input, observationModel: Input, covarienceOfObservationNoise: Input) -> Self
}

// MARK: Double as Kalman input
extension Double: KalmanInput {
    public var transposed: Double {
        return self
    }
    
    public var inversed: Double {
        return 1 / self
    }
    
    public var additionToUnit: Double {
        return 1 - self
    }
}
