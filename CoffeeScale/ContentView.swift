//
//  ContentView.swift
//  CoffeeScale
//
//  Created by Dmitry on 06.06.2024.
//

import SwiftUI
import Charts

struct ContentView: View {
    @ObservedObject var bluetoothScale = BluetoothScale()
    @ObservedObject var stopWatch = StopWatch()
    @State private var smartStart = false
    @State var weightData = [Constants.initialData]
    @State var flowrateData = [Constants.initialData]
    @State var doseWeight: Float = 0
    @State var prevMeasurementDate: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    @State var prevWeight: Float = 0.0
    @State var sameWeightCount: Int = 0
    @State var startDate: Date = Date.now
    struct ChartData: Identifiable, Equatable {
        var id: TimeInterval //{ Date().timeIntervalSince1970 }
        var timestamp: TimeInterval
        var weight: Float
    }
    enum Constants {
        static let minDoseWeight: Float = 0.2
        static let updateWeightInterval = 0.1
        static let updateFlowInterval = 1.0
        static let initialData: ChartData = ChartData(id: Date.now.timeIntervalSince1970, timestamp: Date.now.timeIntervalSince1970, weight: 0.0)
        static let maxSameWeightCount = 2
    }
    let weightChartTimer = Timer.publish(
        every: Constants.updateWeightInterval,
        on: .main,
        in: .common
    ).autoconnect()
    let flowChartTimer = Timer.publish(
        every: Constants.updateFlowInterval,
        on: .main,
        in: .common
    ).autoconnect()
    
    var body: some View {
        //MARK: TOP VALUES
        VStack(spacing: 20) {
            HStack(spacing: 0) {
                VStack {
                    Text("WEIGHT (g)")
                    Text(String(format: "%.1f", bluetoothScale.weight))
                        .font(.system(size: 37, weight: .semibold, design: .rounded))
                }
                .frame(width: UIScreen.main.bounds.width * 0.3)
                VStack {
                    Text("DOSE (g)")
                        .font(.system(size: -1))
                    if doseWeight > Constants.minDoseWeight {
                        Text(String(format: "%.1f", doseWeight))
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                    } else {
                        Text("--")
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                    }
                }
                .frame(width: UIScreen.main.bounds.width * 0.3)
                VStack {
                    Text("FLOWRATE (g/s)")
                        .font(.system(size: -1))
                    Text(String(format: "%.1f", bluetoothScale.flowrate))
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                }
                .frame(width: UIScreen.main.bounds.width * 0.3)
            }
            .padding()
            HStack(spacing: 0) {
                
                VStack {
                    Text("TIME")
                    Text(String(format: "%@", getFormattedString(stopWatch.elapsedTime)))
                        .font(.system(size: 37, weight: .semibold, design: .monospaced))
                }
                .frame(width: UIScreen.main.bounds.width * 0.45)
                VStack {
                    Text("BREW RATIO")
                    if doseWeight > 0.1 {
                        Text(String(format: "1:%.1f", bluetoothScale.weight/doseWeight > 0 ? bluetoothScale.weight/doseWeight : 0.0))
                            .font(.system(size: 37, weight: .semibold, design: .monospaced))
                    } else {
                        Text("-:-.-")
                            .font(.system(size: 37, weight: .semibold, design: .monospaced))
                    }
                }
                .frame(width: UIScreen.main.bounds.width * 0.45)
            }
            
            //MARK: CHARTS
            //MARK: 1. Weight chart
            Chart {
                ForEach(weightData) { data in
                    LineMark(x: .value("Time", data.timestamp),
                             y: .value("Weight", data.weight))
                }
                //.symbol(.circle)
                .interpolationMethod(.monotone)
                .foregroundStyle(Color.accentColor)
                ForEach(weightData) { data in
                    AreaMark(x: .value("Time", data.timestamp),
                             y: .value("Weight", data.weight))
                }
                .foregroundStyle(
                    LinearGradient(
                        gradient:
                            Gradient(colors:
                                        [Color.accentColor.opacity(1),
                                         Color.accentColor.opacity(0)]),
                        startPoint: .top,
                        endPoint: .bottom))
                .interpolationMethod(.monotone)
            }
            .onReceive(weightChartTimer, perform: updateWeightData)
            .animation(.easeInOut(duration: Constants.updateWeightInterval * Double(Constants.maxSameWeightCount) * 5), value: weightData)
            .padding()
            .chartXScale(domain: (weightData.first?.timestamp ?? 0)...(weightData.last?.timestamp ?? 0))
            .chartXAxis {
                AxisMarks(position: .bottom, values: .automatic(desiredCount: 6)) {
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.minute().second())
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 6))
            }
            
            //MARK: 2. Flowrate chart
            if (stopWatch.state != .stopped && self.bluetoothScale.state != .disconnected) {
                Chart {
                    ForEach(flowrateData) { data in
                        BarMark(x: .value("Time", data.timestamp),
                                y: .value("Weight", data.weight))
                    }
                    .cornerRadius(15)
                }
                .frame(height:100)
                .chartXScale(domain: (flowrateData.first?.timestamp ?? 0)...(flowrateData.last?.timestamp ?? 0))
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 6)) {
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.minute().second())
                    }
                }
                .animation(.easeInOut(duration: Constants.updateFlowInterval / 2), value: flowrateData)
                .onReceive(flowChartTimer, perform: updateFlowData)
                .padding()
            }
            
            //MARK: Guide messages
            if self.bluetoothScale.state == .disconnected {
                HStack(spacing: 0) {
                    Text("ℹ️")
                        .font(.system(size: 40))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 10)
                    Text("Power on the scales \nand press Find to find it")
                        .padding(.vertical, 10)
                        .padding(.horizontal, 10)
                }
                .frame(width: UIScreen.main.bounds.width * 0.9, height:100)
                .background(.yellow.opacity(0.3))
                .cornerRadius(10)
            } else {
                if !smartStart && stopWatch.state == .stopped && doseWeight < Constants.minDoseWeight {
                    HStack(spacing: 0) {
                        Text("ℹ️")
                            .font(.system(size: 40))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 10)
                        Text("Weigh the ground coffee \nand press Dose ")
                            .padding(.vertical, 10)
                            .padding(.horizontal, 10)
                    }
                    .frame(width: UIScreen.main.bounds.width * 0.9, height:100)
                    .background(.yellow.opacity(0.3))
                    .cornerRadius(10)
                }
                if !smartStart && stopWatch.state == .stopped && doseWeight > Constants.minDoseWeight {
                    HStack(spacing: 0) {
                        Text("ℹ️")
                            .font(.system(size: 40))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 10)
                        Text("Ready to brew! \nPress Start to start the timer. ")
                            .padding(.vertical, 10)
                            .padding(.horizontal, 10)
                    }
                    .frame(width: UIScreen.main.bounds.width * 0.9, height:100)
                    .background(.yellow.opacity(0.3))
                    .cornerRadius(10)
                }
                if smartStart && stopWatch.state == .stopped && doseWeight < Constants.minDoseWeight {
                    HStack(spacing: 0) {
                        Text("ℹ️")
                            .font(.system(size: 40))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 10)
                        Text("STEP 1 of 2: \nWeigh the ground coffee and press Dose")
                            .padding(.vertical, 10)
                            .padding(.horizontal, 10)
                    }
                    .frame(width: UIScreen.main.bounds.width * 0.9, height:100)
                    .background(.yellow.opacity(0.3))
                    .cornerRadius(10)
                }
                if smartStart && stopWatch.state == .stopped && doseWeight > Constants.minDoseWeight {
                    HStack(spacing: 0) {
                        Text("ℹ️")
                            .font(.system(size: 40))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 10)
                        Text("STEP 2 of 2: \nStart pouring and the timer will start automatically")
                            .padding(.vertical, 10)
                            .padding(.horizontal, 10)
                    }
                    .frame(width: UIScreen.main.bounds.width * 0.9, height:100)
                    .background(.yellow.opacity(0.3))
                    .cornerRadius(10)
                }
                if !smartStart && stopWatch.state == .waiting && doseWeight > Constants.minDoseWeight {
                    HStack(spacing: 0) {
                        Text("ℹ️")
                            .font(.system(size: 40))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 10)
                        Text("Wait for taring")
                            .padding(.vertical, 10)
                            .padding(.horizontal, 10)
                    }
                    .frame(width: UIScreen.main.bounds.width * 0.9, height:100)
                    .background(.yellow.opacity(0.3))
                    .cornerRadius(10)
                }
            }
            
            //MARK: BUTTONS
            Toggle("AUTO START", isOn: $smartStart)
                .frame(width: UIScreen.main.bounds.width * 0.45)
            
            HStack(spacing: 0) {
                if self.bluetoothScale.state == .disconnected {
                    Button(action: {
                        doseWeight = bluetoothScale.weight
                        self.bluetoothScale.sendZero()
                    }) {
                        TimerButton(label: "DOSE", buttonColor: .gray, textColor: .white, size: "small")
                    }
                    .disabled(true)
                    Button(action: {bluetoothScale.scan()}) {
                        TimerButton(label: "FIND", buttonColor: .green, textColor: .white, size: "big")
                    }
                    Button(action: {resetBrewing()}) {
                        TimerButton(label: "RESET", buttonColor: .gray, textColor: .white, size: "small")
                    }
                    .disabled(true)
                } else {
                    if stopWatch.state == .stopped {
                        if smartStart && doseWeight < Constants.minDoseWeight {
                            // CASE "SMART BREWING", STEP 1:
                            // Smart brewing turned on
                            // Ready to get grinded coffee weight
                            Button(action: {
                                doseWeight = bluetoothScale.weight
                                self.bluetoothScale.sendZero()
                                self.bluetoothScale.switchToGramms()
                                weightData.removeAll()
                                flowrateData.removeAll()
                            }) {
                                TimerButton(label: "DOSE", buttonColor: .blue, textColor: .white, size: "small")
                            }
                            Button(action: {startBrewing()}) {
                                TimerButton(label: "START", buttonColor: .gray, textColor: .white, size: "big")
                            }
                            .disabled(true)
                            Button(action: {resetBrewing()}) {
                                TimerButton(label: "RESET", buttonColor: .blue, textColor: .white, size: "small")
                            }
                        }
                        if smartStart && doseWeight > Constants.minDoseWeight {
                            // CASE "SMART BREWING", STEP 2:
                            // Smart brewing turned on
                            // Ready to get grinded coffee weight
                            Button(action: {
                                doseWeight = bluetoothScale.weight
                                self.bluetoothScale.sendZero()
                            }) {
                                TimerButton(label: "DOSE", buttonColor: .blue, textColor: .white, size: "small")
                            }
                            .disabled(true)
                            Button(action: {startBrewing()}) {
                                TimerButton(label: "START", buttonColor: .gray, textColor: .white, size: "big")
                            }
                            .disabled(!smartStart)
                            .onChange(of: bluetoothScale.weight) {
                                if bluetoothScale.weight > Constants.minDoseWeight {
                                    self.stopWatch.start()
                                }
                            }
                            Button(action: {resetBrewing() }) {
                                TimerButton(label: "RESET", buttonColor: .blue, textColor: .white, size: "small")
                            }
                            
                        }
                        if !smartStart {
                            Button(action: {
                                doseWeight = bluetoothScale.weight
                                self.bluetoothScale.sendZero()
                            }) {
                                TimerButton(label: "DOSE", buttonColor: .blue, textColor: .white, size: "small")
                            }
                            Button(action: {startBrewing()}) {
                                TimerButton(label: "START", buttonColor: .blue, textColor: .white, size: "big")
                            }
                            Button(action: {resetBrewing()}) {
                                TimerButton(label: "RESET", buttonColor: .blue, textColor: .white, size: "small")
                            }
                        }
                    }
                    if stopWatch.state == .running {
                        Button(action: {
                            doseWeight = bluetoothScale.weight
                            self.bluetoothScale.sendZero()
                        }) {
                            TimerButton(label: "DOSE", buttonColor: .gray, textColor: .white, size: "small")
                        }
                        .disabled(true)
                        Button(action: {self.stopWatch.pause()}) {
                            TimerButton(label: "PAUSE", buttonColor: .blue, textColor: .white, size: "big")
                        }
                        Button(action: {resetBrewing()}) {
                            TimerButton(label: "RESET", buttonColor: .gray, textColor: .white, size: "small")
                        }
                        .disabled(true)
                        
                    }
                    if stopWatch.state == .paused {
                        Button(action: {doseWeight = bluetoothScale.weight}) {
                            TimerButton(label: "DOSE", buttonColor: .gray, textColor: .white, size: "small")
                        }
                        .disabled(true)
                        Button(action: {self.stopWatch.start()}) {
                            TimerButton(label: "GO ON", buttonColor: .blue, textColor: .white, size: "big")
                        }
                        Button(action: {resetBrewing()}) {
                            TimerButton(label: "FINISH", buttonColor: .blue, textColor: .white, size: "small")
                        }
                    }
                    if stopWatch.state == .waiting {
                        Button(action: {
                            doseWeight = bluetoothScale.weight
                            self.bluetoothScale.sendZero()
                        }) {
                            TimerButton(label: "DOSE", buttonColor: .gray, textColor: .white, size: "small")
                        }
                        .disabled(true)
                        Button(action: {self.stopWatch.pause()}) {
                            TimerButton(label: "PAUSE", buttonColor: .gray, textColor: .white, size: "big")
                        }
                        .disabled(true)
                        Button(action: {resetBrewing()}) {
                            TimerButton(label: "RESET", buttonColor: .gray, textColor: .white, size: "small")
                        }
                        .disabled(true)
                    }
                }
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
    }
    
    func updateWeightData(_ : Date) {
        if stopWatch.state == .running {
            let currentMeasurementDate = bluetoothScale.measurementDate
            var currentWeight = bluetoothScale.weight
            let currentElapsedTime = stopWatch.elapsedTime
            if (weightData.last?.weight ?? 0.0 > bluetoothScale.weight) {
                currentWeight = weightData.last?.weight ?? 0.0 // It's for Rao Spin etc
            }
            //print("Is it the same? \(currentWeight - (weightData.last?.weight ?? 0.0) < Constants.minDoseWeight)")
            if (!weightData.isEmpty)
                && (currentWeight - (weightData.last?.weight ?? 0.0) < Constants.minDoseWeight)
                && (sameWeightCount < Constants.maxSameWeightCount) {
                print("The weight is the same \(sameWeightCount) times")
                sameWeightCount = sameWeightCount + 1
            } else {
                weightData.append(ChartData(id: Date.now.timeIntervalSinceReferenceDate - startDate.timeIntervalSinceReferenceDate, timestamp: TimeInterval(currentElapsedTime), weight: currentWeight > 0 ? currentWeight : 0.0))
                print("The weight valeu is added")
                sameWeightCount = 0
            }
            print("WeightData>> dates: \(Date.now.timeIntervalSinceReferenceDate - startDate.timeIntervalSinceReferenceDate); time: \(TimeInterval(currentElapsedTime)); weight: \(currentWeight); measurementDate: \(currentMeasurementDate)")
            
            var maxWeight = weightData.max { $0.weight < $1.weight }
            print("WMAX>> weight: \(String(describing: maxWeight?.weight))")
        }
    }
    
    func updateFlowData(_ : Date) {
        if stopWatch.state == .running {
            let currentMeasurementDate = bluetoothScale.measurementDate
            var currentWeight = bluetoothScale.weight
            let currentElapsedTime = stopWatch.elapsedTime
            if (prevWeight > currentWeight) {
                currentWeight = prevWeight // It's for Rao Spin etc
            }
            let flowrate = ( 1000 * (currentWeight - prevWeight) / Float(currentMeasurementDate - prevMeasurementDate) )
            flowrateData.append(ChartData(id: Date.now.timeIntervalSinceReferenceDate - startDate.timeIntervalSinceReferenceDate, timestamp: TimeInterval(currentElapsedTime), weight: flowrate > 0 ? flowrate : 0.0))
            prevMeasurementDate = currentMeasurementDate
            prevWeight = currentWeight
            
            print("FlowData>> time: \(currentElapsedTime); flowrate: \(flowrate); prevWeight: \(prevWeight); weight: \(currentWeight); measurementDate: \(currentMeasurementDate)")
        }
    }
    
    func startBrewing() {
        print("Brewing started")
        self.stopWatch.wait()
        self.bluetoothScale.switchToGramms()
        weightData.removeAll()
        flowrateData.removeAll()
        sameWeightCount = 0
        if (bluetoothScale.weight > Constants.minDoseWeight) {
            self.bluetoothScale.sendZero()
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { waitingTimer in
                if bluetoothScale.weight < Constants.minDoseWeight {
                    waitingTimer.invalidate()
                    prevMeasurementDate = bluetoothScale.measurementDate
                    startDate = Date.now
                    self.stopWatch.start()
                }
            }
        } else {
            prevMeasurementDate = bluetoothScale.measurementDate
            startDate = Date.now
            self.stopWatch.start()
        }
    }
    
    func resetBrewing() {
        print("Finish brewing. Reset data.")
        //print("WeightData: \(weightData)")
        weightData.removeAll()
        flowrateData.removeAll()
        doseWeight = 0
        prevWeight = 0.0
        self.bluetoothScale.sendZero()
        self.stopWatch.stop()
    }
    
}

struct TimerButton: View {
    let label: String
    let buttonColor: Color
    let textColor: Color
    let size: String
    
    var body: some View {
        let multiplicator = size == "big" ? 1.5 : 1
        Text(label)
            .font(.system(size: 16 * CGFloat(multiplicator), weight: .semibold, design: .rounded))
            .frame(width: UIScreen.main.bounds.width * 0.3, height: 70 * CGFloat(multiplicator))
            .foregroundStyle(textColor)
            .padding(.vertical, 0)
            .padding(.horizontal, 0)
            .background(buttonColor)
            .clipShape(Circle())
    }
}

func getFormattedString(_ seconds: Float) -> String {
    let ti = NSInteger(seconds)
    let ms = Int((seconds.truncatingRemainder(dividingBy: 1)) * 10)
    let seconds = ti % 60
    let minutes = (ti / 60) % 60
    return String(format: "%0.1d:%0.2d.%0.1d",minutes,seconds,ms)
}

#Preview {
    ContentView()
}

