//
//  KalmanFilter.swift
//  KalmanFilter
//
//  Created by Oleksii on 18/08/16.
//  Copyright © 2016 Oleksii Dykan. All rights reserved.
//  https://github.com/wearereasonablepeople/KalmanFilter/blob/master/KalmanFilter/KalmanFilter.swift
//
import Foundation

/**
 Conventional Kalman Filter
 */
public struct KalmanFilter<Type: KalmanInput>: KalmanFilterType {
    /// x̂_k|k-1
    public let stateEstimatePrior: Type
    /// P_k|k-1
    public let errorCovariancePrior: Type
    
    public init(stateEstimatePrior: Type, errorCovariancePrior: Type) {
        self.stateEstimatePrior = stateEstimatePrior
        self.errorCovariancePrior = errorCovariancePrior
    }
    
    /**
     Predict step in Kalman filter.
     
     - parameter stateTransitionModel: F_k
     - parameter controlInputModel: B_k
     - parameter controlVector: u_k
     - parameter covarianceOfProcessNoise: Q_k
     
     - returns: Another instance of Kalman filter with predicted x̂_k and P_k
     */
    public func predict(stateTransitionModel: Type, controlInputModel: Type, controlVector: Type, covarianceOfProcessNoise: Type) -> KalmanFilter {
        // x̂_k|k-1 = F_k * x̂_k-1|k-1 + B_k * u_k
        let predictedStateEstimate = stateTransitionModel * stateEstimatePrior + controlInputModel * controlVector
        // P_k|k-1 = F_k * P_k-1|k-1 * F_k^t + Q_k
        let predictedEstimateCovariance = stateTransitionModel * errorCovariancePrior * stateTransitionModel.transposed + covarianceOfProcessNoise
        
        return KalmanFilter(stateEstimatePrior: predictedStateEstimate, errorCovariancePrior: predictedEstimateCovariance)
    }
    
    /**
     Update step in Kalman filter. We update our prediction with the measurements that we make
     
     - parameter measurement: z_k
     - parameter observationModel: H_k
     - parameter covarienceOfObservationNoise: R_k
     
     - returns: Updated with the measurements version of Kalman filter with new x̂_k and P_k
     */
    public func update(measurement: Type, observationModel: Type, covarienceOfObservationNoise: Type) -> KalmanFilter {
        // H_k^t transposed. We cache it improve performance
        let observationModelTransposed = observationModel.transposed
        
        // ỹ_k = z_k - H_k * x̂_k|k-1
        let measurementResidual = measurement - observationModel * stateEstimatePrior
        // S_k = H_k * P_k|k-1 * H_k^t + R_k
        let residualCovariance = observationModel * errorCovariancePrior * observationModelTransposed + covarienceOfObservationNoise
        // K_k = P_k|k-1 * H_k^t * S_k^-1
        let kalmanGain = errorCovariancePrior * observationModelTransposed * residualCovariance.inversed
        
        // x̂_k|k = x̂_k|k-1 + K_k * ỹ_k
        let posterioriStateEstimate = stateEstimatePrior + kalmanGain * measurementResidual
        // P_k|k = (I - K_k * H_k) * P_k|k-1
        let posterioriEstimateCovariance = (kalmanGain * observationModel).additionToUnit * errorCovariancePrior
        
        return KalmanFilter(stateEstimatePrior: posterioriStateEstimate, errorCovariancePrior: posterioriEstimateCovariance)
    }
}

//var filter = KalmanFilter(stateEstimatePrior: 0.0, errorCovariancePrior: 1.0)
//let prediction = filter.predict(1, controlInputModel: 0, controlVector: 0, covarianceOfProcessNoise: Q) //  Q > 0, loss of certainty each update
//let update = prediction.update(measurement, observationModel: 1, covarienceOfObservationNoise: R) // R (if one dimension) = standard deviation of the measurement
