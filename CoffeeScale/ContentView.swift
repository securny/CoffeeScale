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
    @State var coffeeWeight: Float = 0
    var xAxisValues: [String] = ["0:00","0:20","0:40"
                                 ,"1:00","1:20","1:40"
                                 ,"2:00","2:20","2:40"
                                 ,"3:00","3:20","3:40"
                                 ,"4:00","4:20","4:40"
                                 ,"5:00","5:20","5:40"
                                 ,"6:00","6:20","6:40"
                                 ,"7:00","7:20","7:40"
                                 ,"8:00","8:20","8:40"
                                 ,"9:00","9:20","9:40"]
    //var yAxisValues: [Float] = [0.0,50.0]
    struct ChartData: Identifiable {
        var id = UUID()
        var timestamp: String
        var weight: Float
    }
    enum Constants {
        static let updateInterval = 1.0
        static let initialData: ChartData = ChartData(timestamp: getFormattedString(0,IsMsTrue: false), weight: 0.0)
        static let xAxisInterval = 15.0
        static let yAxisInterval = 20.0
    }
    let timer = Timer.publish(
        every: Constants.updateInterval,
        on: .main,
        in: .common
    ).autoconnect()
        
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 0) {
                VStack {
                    Text("WEIGHT (g)")
                    Text(String(format: "%.1f", bluetoothScale.weight))
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                }
                .frame(width: UIScreen.main.bounds.width * 0.45)
                VStack {
                    Text("TIME")
                    Text(String(format: "%@", getFormattedString(stopWatch.elapsedTime,IsMsTrue: true)))
                        .font(.system(size: 40, weight: .semibold, design: .monospaced))
                }
                .frame(width: UIScreen.main.bounds.width * 0.5)
            }
            HStack(spacing: 0) {
                VStack {
                    Text("FLOWRATE (g/s)")
                    Text(String(format: "%.1f", bluetoothScale.flowrate))
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                }
                .frame(width: UIScreen.main.bounds.width * 0.45)
                VStack {
                    Text("BREW RATIO")
                    if coffeeWeight > 0.1 {
                        Text(String(format: "1:%.1f", bluetoothScale.weight/coffeeWeight > 0 ? bluetoothScale.weight/coffeeWeight : 0.0))
                            .font(.system(size: 40, weight: .semibold, design: .monospaced))
                    } else {
                        Text("-:-.-")
                            .font(.system(size: 40, weight: .semibold, design: .monospaced))
                    }
                }
                .frame(width: UIScreen.main.bounds.width * 0.5)
            }
            
            // CHARTS
            Chart {
                ForEach(weightData) { data in
                    LineMark(x: .value("Time", data.timestamp),
                             y: .value("Weight", data.weight))
                }
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
            .onReceive(timer, perform: updateData)
            .chartXAxis {
                AxisMarks(values: xAxisValues) {
                    AxisGridLine()
                    AxisValueLabel(centered: true)
                }
            }
            //.chartYAxis {
            //    AxisMarks(
            //        values: yAxisValues)
            //}
            
            if (stopWatch.state != .stopped) {
                Chart {
                    ForEach(flowrateData) { data in
                        BarMark(x: .value("Time", data.timestamp),
                                y: .value("Weight", data.weight))
                    }
                    .cornerRadius(15)
                }
                .frame(height:100)
                .chartXAxis {
                    AxisMarks(values: xAxisValues) {
                        AxisGridLine()
                        AxisValueLabel(centered: true)
                    }
                }
            }

            if !smartStart && stopWatch.state == .stopped && coffeeWeight < 0.1 {
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
            if smartStart && stopWatch.state == .stopped && coffeeWeight < 0.1 {
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
            if smartStart && stopWatch.state == .stopped && coffeeWeight > 0.1 {
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
            
            // BUTTONS
                Toggle("AUTO START", isOn: $smartStart)
                    .frame(width: UIScreen.main.bounds.width * 0.45)

                        
            HStack(spacing: 0) {
                if stopWatch.state == .stopped  {
                    if smartStart && coffeeWeight < 0.1 {
                            // CASE "SMART BREWING", STEP 1:
                            // Smart brewing turned on
                            // Ready to get grinded coffee weight
                        Button(action: {
                            coffeeWeight = bluetoothScale.weight
                        }) {
                            TimerButton(label: "DOSE", buttonColor: .blue, textColor: .white, size: "small")
                        }
                            Button(action: {
                                coffeeWeight = bluetoothScale.weight
                                self.bluetoothScale.sendZero()
                            }) {
                                TimerButton(label: "START", buttonColor: .gray, textColor: .white, size: "big")
                            }
                            .disabled(true)
                            Button(action: {
                                coffeeWeight = 0
                                self.bluetoothScale.sendZero()
                            }) {
                                TimerButton(label: "RESET", buttonColor: .gray, textColor: .white, size: "small")
                            }
                            .disabled(true)
                    }
                    if smartStart && coffeeWeight > 0.1 {
                        // CASE "SMART BREWING", STEP 2:
                        // Smart brewing turned on
                        // Ready to get grinded coffee weight
                        Button(action: {
                            coffeeWeight = bluetoothScale.weight
                        }) {
                            TimerButton(label: "DOSE", buttonColor: .blue, textColor: .white, size: "small")
                        }
                        .disabled(true)
                        Button(action: {
                            self.bluetoothScale.sendZero()
                            self.bluetoothScale.switchToGramms()
                            weightData.removeAll()
                            flowrateData.removeAll()
                            self.stopWatch.start()
                        }) {
                            TimerButton(label: "START", buttonColor: .gray, textColor: .white, size: "big")
                        }
                        .disabled(!smartStart)
                        .onChange(of: bluetoothScale.weight) {
                            if bluetoothScale.weight > 1.0 {
                                self.bluetoothScale.sendZero()
                                self.bluetoothScale.switchToGramms()
                                weightData.removeAll()
                                flowrateData.removeAll()
                                self.stopWatch.start()
                            }
                        }
                        Button(action: {
                            weightData.removeAll()
                            flowrateData.removeAll()
                            coffeeWeight = 0
                            self.bluetoothScale.sendZero()
                        }) {
                            TimerButton(label: "RESET", buttonColor: .blue, textColor: .white, size: "small")
                        }

                    }
                    if !smartStart {
                        Button(action: {
                            coffeeWeight = bluetoothScale.weight
                            self.bluetoothScale.sendZero()
                        }) {
                            TimerButton(label: "DOSE", buttonColor: .blue, textColor: .white, size: "small")
                        }
                        Button(action: {
                            self.bluetoothScale.sendZero()
                            self.bluetoothScale.switchToGramms()
                            weightData.removeAll()
                            flowrateData.removeAll()
                            self.stopWatch.start()
                        }) {
                            TimerButton(label: "START", buttonColor: .blue, textColor: .white, size: "big")
                        }
                        Button(action: {
                            weightData.removeAll()
                            flowrateData.removeAll()
                            coffeeWeight = 0
                            self.bluetoothScale.sendZero()
                        }) {
                            TimerButton(label: "RESET", buttonColor: .blue, textColor: .white, size: "small")
                        }
                    }
                }
            if stopWatch.state == .running {
                Button(action: {
                    coffeeWeight = bluetoothScale.weight
                    self.bluetoothScale.sendZero()
                }) {
                    TimerButton(label: "DOSE", buttonColor: .gray, textColor: .white, size: "small")
                }
                .disabled(true)
                Button(action: {self.stopWatch.pause()}) {
                    TimerButton(label: "PAUSE", buttonColor: .blue, textColor: .white, size: "big")
                }
                Button(action: {
                    weightData.removeAll()
                    flowrateData.removeAll()
                    coffeeWeight = 0
                    self.bluetoothScale.sendZero()
                    self.stopWatch.stop()
                }) {
                    TimerButton(label: "RESET", buttonColor: .gray, textColor: .white, size: "small")
                }
                .disabled(true)
                
            }
            if stopWatch.state == .paused {
                    Button(action: {
                        coffeeWeight = bluetoothScale.weight
                    }) {
                        TimerButton(label: "DOSE", buttonColor: .gray, textColor: .white, size: "small")
                    }
                    .disabled(true)
                Button(action: {self.stopWatch.start()}) {
                    TimerButton(label: "GO ON", buttonColor: .blue, textColor: .white, size: "big")
                }
                Button(action: {
                    weightData.removeAll()
                    flowrateData.removeAll()
                    coffeeWeight = 0
                    self.bluetoothScale.sendZero()
                    self.stopWatch.stop()
                }) {
                    TimerButton(label: "RESET", buttonColor: .blue, textColor: .white, size: "small")
                }
            }
            }
        }
        .padding()
    }

    func updateData(_ : Date) {
        if stopWatch.state == .running {
            let prevWeight: Float = weightData.last?.weight ?? 0.0
            weightData.append(ChartData(timestamp: getFormattedString(stopWatch.elapsedTime,IsMsTrue: false), weight: bluetoothScale.weight > 0 ? bluetoothScale.weight : 0.0))
            let flowrate = ((bluetoothScale.weight) - prevWeight) / Float(Constants.updateInterval)
            flowrateData.append(ChartData(timestamp: getFormattedString(stopWatch.elapsedTime,IsMsTrue: false), weight: flowrate > 0 ? flowrate : 0.0))
        }
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
            .font(.system(size: 20 * CGFloat(multiplicator), weight: .semibold, design: .rounded))
            .frame(width: UIScreen.main.bounds.width * 0.3, height: 80 * CGFloat(multiplicator))
            .foregroundStyle(textColor)
            .padding(.vertical, 0)
            .padding(.horizontal, 0)
            .background(buttonColor)
            .clipShape(Circle())
    }
}

func getFormattedString(_ seconds: Float, IsMsTrue: Bool) -> String {
    let ti = NSInteger(seconds)
    let ms = Int((seconds.truncatingRemainder(dividingBy: 1)) * 10)
    let seconds = ti % 60
    let minutes = (ti / 60) % 60

    if (!IsMsTrue) {
        return String(format: "%0.1d:%0.2d",minutes,seconds)
    } else {
        return String(format: "%0.1d:%0.2d.%0.1d",minutes,seconds,ms)
    }
}

#Preview {
    ContentView()
}
