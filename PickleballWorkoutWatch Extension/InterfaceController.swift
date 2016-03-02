//
//  InterfaceController.swift
//  PickleballWorkoutWatch Extension
//
//  Created by Ronny Hendrickx on 2/28/16.
//  Copyright © 2016 Ronny Hendrickx. All rights reserved.
//

import WatchKit
import Foundation
import HealthKit


extension Double {
    func format(f: String) -> String {
        return String(format: "%\(f)f", self)
    }
}




class InterfaceController: WKInterfaceController, HKWorkoutSessionDelegate {
    //MARK: outlets
    
    @IBOutlet var workoutButton: WKInterfaceButton!
    
    @IBOutlet var activeEnergyBurnedLabel: WKInterfaceLabel!
    
    @IBOutlet var distanceLabel: WKInterfaceLabel!
    
    @IBOutlet var heartRateLabel: WKInterfaceLabel!
    
    //MARK: properties
    
    let healthStore = HKHealthStore()
    
    // Used to track the current `HKWorkoutSession`.
    var currentWorkoutSession: HKWorkoutSession?
    
    var workoutBeginDate: NSDate?
    var workoutEndDate: NSDate?
    
    var isWorkoutRunning = false
    
    var currentQuery: HKQuery?
    var currentDistanceQuery: HKQuery?
    
    
    var activeEnergySamples = [HKQuantitySample]()
    var activeDistanceSamples = [HKQuantitySample]()
    
    // Start with a zero quantity.
    var currentActiveEnergyQuantity = HKQuantity(unit: HKUnit.kilocalorieUnit(), doubleValue: 0.0)
    var currentHeartReateQuantity = HKQuantity(unit: HKUnit.countUnit().unitDividedByUnit(HKUnit.minuteUnit()), doubleValue: 0.0)
    var currentDistanceQuantity = HKQuantity(unit: HKUnit.mileUnit() , doubleValue: 0.0)
    
    
    
    
    let doubleFormat = ".1"
    
    //MARK: standard functions
    
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        
        // Configure interface objects here.
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        
        // Only proceed if health data is available.
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        // We need to be able to write workouts, so they display as a standalone workout in the Activity app on iPhone.
        // We also need to be able to write Active Energy Burned to write samples to HealthKit to later associating with our app.
        
        let typesToShare = Set([
            HKObjectType.workoutType(),
            HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierActiveEnergyBurned)!,
            HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDistanceWalkingRunning)!,
            HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeartRate)!
            ])
        
        let typesToRead = Set([
            HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierActiveEnergyBurned)!,
            HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDistanceWalkingRunning)!,
            HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeartRate)!
            ])
        
        
        healthStore.requestAuthorizationToShareTypes(typesToShare, readTypes: typesToRead) { success, error in
            if let error = error where !success {
                print("You didn't allow HealthKit to access these read/write data types. In your app, try to handle this error gracefully when a user decides not to provide access. The error was: \(error.localizedDescription). If you're using a simulator, try it on a device.")
            }
        }
        
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
        workoutButton.setTitle("test")
    }
    
    //MARK: actions
    
    @IBAction func toggleWorkout() {
        
        if isWorkoutRunning {
            guard let workoutSession = currentWorkoutSession else { return }
            
            // end workout
            healthStore.endWorkoutSession(workoutSession)
            isWorkoutRunning = false
        } else {
            // Begin workout.
            isWorkoutRunning = true
            
            // Clear the local Active Energy Burned quantity when beginning a workout session.
            currentActiveEnergyQuantity = HKQuantity(unit: HKUnit.kilocalorieUnit(), doubleValue: 0.0)
            currentHeartReateQuantity = HKQuantity(unit: HKUnit.countUnit().unitDividedByUnit(HKUnit.minuteUnit()), doubleValue: 0.0)
            currentDistanceQuantity = HKQuantity(unit: HKUnit.footUnit() , doubleValue: 0.0)
            
            currentQuery = nil
            activeEnergySamples = []
            activeDistanceSamples = []
            
            //TODO set switch for indoor/outdoor
            
            let workoutSession = HKWorkoutSession(activityType: .Tennis, locationType: .Outdoor)
            workoutSession.delegate = self
            
            currentWorkoutSession = workoutSession
            
            healthStore.startWorkoutSession(workoutSession)
        }
    }
    
    
    
    
    // MARK: Convenience
    
    
    
    
    /*
    Create and save an HKWorkout with the amount of Active Energy Burned we accumulated during the HKWorkoutSession.
    
    Additionally, associate the Active Energy Burned samples to our workout to facilitate showing our app as credited for these samples in the Move graph in the Activity app on iPhone.
    */
    func saveWorkout() {
        // Obtain the `HKObjectType` for active energy burned.
        guard let activeEnergyType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierActiveEnergyBurned) else { return }
        
        guard let activeDistanceType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDistanceWalkingRunning) else {return}
        //let distanceUnit = HKUnit.mileUnit()
        
        // Only proceed if both `beginDate` and `endDate` are non-nil.
        guard let beginDate = workoutBeginDate, endDate = workoutEndDate else { return }
        
        /*
        NOTE: There is a known bug where activityType property of HKWorkoutSession returns 0, as of iOS 9.1 and watchOS 2.0.1. So, rather than set it using the value from the `HKWorkoutSession`, set it explicitly for the HKWorkout object.
        */
        
        //currentDistanceQuantity = getCurrentDistance(beginDate, eDate: endDate)
       
        
        self.fetchTotalDistanceWithCompletionHandler{ (result, error) -> Void in
            if let unWrappedError = error {
                print("\(unWrappedError)")
            }
        }
        
        
        
        let workout = HKWorkout(activityType: HKWorkoutActivityType.Tennis, startDate: beginDate, endDate: endDate, duration: endDate.timeIntervalSinceDate(beginDate), totalEnergyBurned: currentActiveEnergyQuantity, totalDistance: currentDistanceQuantity, metadata: nil)
        
        // try total distance like this.....
        
       // let workout = HKWorkout(activityType: HKWorkoutActivityType.Tennis, startDate: beginDate, endDate: endDate, duration: endDate.timeIntervalSinceDate(beginDate), totalEnergyBurned: currentActiveEnergyQuantity, totalDistance: HKQuantity(unit: HKUnit.mileUnit(), doubleValue: 0.0), metadata: nil)

        
        
        
        // Save the array of samples that produces the energy burned total
        let finalActiveEnergySamples = activeEnergySamples
        let finalDistanceSamples = activeDistanceSamples
        
        
        guard healthStore.authorizationStatusForType(activeEnergyType) == .SharingAuthorized && healthStore.authorizationStatusForType(HKObjectType.workoutType()) == .SharingAuthorized else { return }
        
        guard healthStore.authorizationStatusForType(activeDistanceType) == .SharingAuthorized && healthStore.authorizationStatusForType(HKObjectType.workoutType()) == .SharingAuthorized else { return }
        
        healthStore.saveObject(workout) { [unowned self] success, error in
            if let error = error where !success {
                print("An error occurred saving the workout. The error was: \(error.localizedDescription)")
                return
            }
            
            // Since HealthKit completion blocks may come back on a background queue, please dispatch back to the main queue.
            if success && finalActiveEnergySamples.count > 0 {
                // Associate the accumulated samples with the workout.
                self.healthStore.addSamples(finalActiveEnergySamples, toWorkout: workout) { success, error in
                    if let error = error where !success {
                        print("An error occurred adding samples to the workout. The error was: \(error.localizedDescription)")
                    }
                }
            }
            if success && finalDistanceSamples.count > 0 {
                // Associate the accumulated samples with the workout.
                self.healthStore.addSamples(finalDistanceSamples, toWorkout: workout) { success, error in
                    if let error = error where !success {
                        print("An error occurred adding samples to the workout. The error was: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    func beginWorkoutOnDate(beginDate: NSDate) {
        // Obtain the `HKObjectType` for active energy burned and the `HKUnit` for kilocalories.
        guard let activeEnergyType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierActiveEnergyBurned) else { return }
        let energyUnit = HKUnit.calorieUnit()
        //let energyUnit = HKUnit.calorieUnit()
       
        //guard let activeDistanceType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDistanceWalkingRunning) else {return}
        //let distanceUnit = HKUnit.mileUnit()
        
        
        // Update properties.
        workoutBeginDate = beginDate
        workoutButton.setTitle("End Workout")
        
        // Set up a predicate to obtain only samples from the local device starting from `beginDate`.
        let datePredicate = HKQuery.predicateForSamplesWithStartDate(beginDate, endDate: nil, options: .None)
        let devicePredicate = HKQuery.predicateForObjectsFromDevices([HKDevice.localDevice()])
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates:[datePredicate, devicePredicate])
        
        /*
        Create a results handler to recreate the samples generated by a query of active energy samples so that they can be associated with this app in the move graph. It should be noted that if your app has different heuristics for active energy burned you can generate your own quantities rather than rely on those from the watch. The sum of your sample's quantity values should equal the energy burned value provided for the workout.
        */
        let sampleHandler = { [unowned self] (samples: [HKQuantitySample]) -> Void in
            dispatch_async(dispatch_get_main_queue()) { [unowned self] in
                
                let initialActiveEnergy = self.currentActiveEnergyQuantity.doubleValueForUnit(energyUnit)
                
                let processedResults: (Double, [HKQuantitySample]) = samples.reduce((initialActiveEnergy, [])) { current, sample in
                    
                    
                    
                    
                    if sample.quantity.isCompatibleWithUnit(energyUnit) {
                        let accumulatedValue = current.0 + sample.quantity.doubleValueForUnit(energyUnit)
                        
                        
                        let ourSample = HKQuantitySample(type: activeEnergyType, quantity: sample.quantity, startDate: sample.startDate, endDate: sample.endDate)
                        
                        return (accumulatedValue, current.1 + [ourSample])
                    } else {
                        return(current.0 ,current.1 )
                    }
                }
                
                // Update the UI.
                self.currentActiveEnergyQuantity = HKQuantity(unit: energyUnit, doubleValue: processedResults.0)
                let temp = processedResults.0/1000
                
                self.activeEnergyBurnedLabel.setText("\(temp.format(self.doubleFormat))")
                
                
                // Update our samples.
                self.activeEnergySamples += processedResults.1
            }
        }
        
        // Create a query to report new Active Energy Burned samples to our app.
        let activeEnergyQuery = HKAnchoredObjectQuery(type: activeEnergyType, predicate: predicate, anchor: nil, limit: Int(HKObjectQueryNoLimit)) { query, samples, deletedObjects, anchor, error in
            if let error = error {
                print("An error occurred with the `activeEnergyQuery`. The error was: \(error.localizedDescription)")
                return
            }
            // NOTE: `deletedObjects` are not considered in the handler as there is no way to delete samples from the watch during a workout.
            guard let activeEnergySamples = samples as? [HKQuantitySample] else { return }
            sampleHandler(activeEnergySamples)
        }
        
        // Assign the same handler to process future samples generated while the query is still active.
        activeEnergyQuery.updateHandler = { query, samples, deletedObjects, anchor, error in
            if let error = error {
                print("An error occurred with the `activeEnergyQuery`. The error was: \(error.localizedDescription)")
                return
            }
            // NOTE: `deletedObjects` are not considered in the handler as there is no way to delete samples from the watch during a workout.
            guard let activeEnergySamples = samples as? [HKQuantitySample] else { return }
            sampleHandler(activeEnergySamples)
        }
        
        currentQuery = activeEnergyQuery
        healthStore.executeQuery(activeEnergyQuery)
        
        // distance query
        /*
        let sampleDistanceHandler = { [unowned self] (samples: [HKQuantitySample]) -> Void in
            dispatch_async(dispatch_get_main_queue()) { [unowned self] in
                
                let initialDistance = self.currentDistanceQuantity.doubleValueForUnit(distanceUnit)
                
                let processedResults: (Double, [HKQuantitySample]) = samples.reduce((initialDistance, [])) { current, sample in
                    
                    if sample.quantity.isCompatibleWithUnit(distanceUnit) {
                        let accumulatedValue = current.0 + sample.quantity.doubleValueForUnit(distanceUnit)
                        
                        let ourSample = HKQuantitySample(type: activeDistanceType, quantity: sample.quantity, startDate: sample.startDate, endDate: sample.endDate)
                        
                        return (accumulatedValue, current.1 + [ourSample]) }
                    else {
                        return(current.0, current.1)
                    }
                }
                
                // Update the UI.
                self.currentDistanceQuantity = HKQuantity(unit: distanceUnit, doubleValue: processedResults.0)
                self.distanceLabel.setText("\(processedResults.0.format(self.doubleFormat))")
                
                // Update our samples.
                self.activeDistanceSamples += processedResults.1
            }
        }
        
        // Create a query to report new distance samples to our app.
        let activeDistanceQuery = HKAnchoredObjectQuery(type: activeDistanceType, predicate: predicate, anchor: nil, limit: Int(HKObjectQueryNoLimit)) { query, samples, deletedObjects, anchor, error in
            if let error = error {
                print("An error occurred with the `activeDistanceQuery`. The error was: \(error.localizedDescription)")
                return
            }
            // NOTE: `deletedObjects` are not considered in the handler as there is no way to delete samples from the watch during a workout.
            guard let activeDistanceSamples = samples as? [HKQuantitySample] else { return }
            sampleDistanceHandler(activeDistanceSamples)
            
        }
        
        // Assign the same handler to process future samples generated while the query is still active.
        activeDistanceQuery.updateHandler = { query, samples, deletedObjects, anchor, error in
            if let error = error {
                print("An error occurred with the `activeDistanceQuery`. The error was: \(error.localizedDescription)")
                return
            }
            // NOTE: `deletedObjects` are not considered in the handler as there is no way to delete samples from the watch during a workout.
            guard let activeDistanceSamples = samples as? [HKQuantitySample] else { return }
            sampleHandler(activeDistanceSamples)
        }
        
        currentDistanceQuery = activeDistanceQuery
        healthStore.executeQuery(activeDistanceQuery)
        
        */
        
        
    }
    
    func endWorkoutOnDate(endDate: NSDate) {
        workoutEndDate = endDate
        
        workoutButton.setTitle("Begin Workout")
        activeEnergyBurnedLabel.setText("0.0")
        distanceLabel.setText("0.0")
        
        
        if let query = currentQuery {
            healthStore.stopQuery(query)
        }
        if let query = currentDistanceQuery {
            healthStore.stopQuery(query)
        }
        
        
        saveWorkout()
    }
    
    func workoutSession(workoutSession: HKWorkoutSession, didChangeToState toState: HKWorkoutSessionState, fromState: HKWorkoutSessionState, date: NSDate) {
        dispatch_async(dispatch_get_main_queue()) { [unowned self] in
            switch toState {
            case .Running:
                self.beginWorkoutOnDate(date)
                
            case .Ended:
                self.endWorkoutOnDate(date)
                
            default:
                print("Unexpected workout session state: \(toState)")
            }
        }
    }
    
    func workoutSession(workoutSession: HKWorkoutSession, didFailWithError error: NSError) {
        print("The workout session failed. The error was: \(error.localizedDescription)")
    }
    
  //  func getCurrentDistancewithcompletionhandler(bDate: NSDate, eDate: NSDate) -> HKQuantity {
        
   //     guard let activeDistanceType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDistanceWalkingRunning) else {return currentDistanceQuantity}
    //    let distanceUnit = HKUnit.mileUnit()
        
        
       /* var sumDistanceQuantity  = HKQuantity(unit: HKUnit.mileUnit() , doubleValue: 0.0)
        
        
        // Set up a predicate to obtain only samples from the local device starting from `beginDate`.
        let datePredicate = HKQuery.predicateForSamplesWithStartDate(bDate, endDate: eDate, options: .None)
        let devicePredicate = HKQuery.predicateForObjectsFromDevices([HKDevice.localDevice()])
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates:[datePredicate, devicePredicate])
        
        //let distanceSample = HKQuantitySample(type: HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDistanceWalkingRunning)!, quantity: currentDistanceQuantity, startDate: bDate, endDate: eDate)
        
        let sumOption = HKStatisticsOptions.CumulativeSum
        
        let statisticsSumQuery = HKStatisticsQuery(quantityType: HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDistanceWalkingRunning)!, quantitySamplePredicate: predicate,
            options: sumOption)
            {  (query, result, error) in
                if let sumQuantity = result?.sumQuantity() {
                  sumDistanceQuantity = sumQuantity
                }
                
        }
        
        // Don't forget to execute the query!
        healthStore.executeQuery(statisticsSumQuery)

        
        return sumDistanceQuantity
*/
     func fetchTotalDistanceWithCompletionHandler(
        completionHandler:(Double?, NSError?)->()) {
            
            guard let beginDate = workoutBeginDate, endDate = workoutEndDate else { return }

            
            let sampleType = HKQuantityType.quantityTypeForIdentifier(
                HKQuantityTypeIdentifierDistanceWalkingRunning)
            
            let predicate = HKQuery.predicateForSamplesWithStartDate(beginDate,
                endDate: endDate, options: .StrictStartDate)
            
            let query = HKStatisticsQuery(quantityType: sampleType!,
                quantitySamplePredicate: predicate,
                options: .CumulativeSum) { query, result, error in
                    
                    if result != nil {
                        completionHandler(nil, error)
                        return
                    }
                    
                    var sumdistanceQuantit = 0.0
                    
                    if let quantity = result!.sumQuantity() {
                        let unit = HKUnit.mileUnit()
                        self.currentDistanceQuantity = quantity
                        sumdistanceQuantit = quantity.doubleValueForUnit(unit)
                    }
                    
                    completionHandler(sumdistanceQuantit, error)
            }
            
            healthStore.executeQuery(query)
        
    }
    
}
