// Composition
class Engine {
  String type;

  Engine(this.type);

  void startEngine() {
    print('$type engine is starting...');
  }
}

// Abstraction
abstract class Car {
  String brand;
  Engine engine;

  Car(this.brand, this.engine);

  void start();

  void showInfo() {
    print('Brand: $brand');
    print('Engine: ${engine.type}');
  }
}

// Inheritance
class ElectricCar extends Car {
  int battery;

  ElectricCar(String brand, Engine engine, this.battery) : super(brand, engine);

  @override
  void start() {
    engine.startEngine();
    print('$brand electric car is ready to drive');
  }

  void showBattery() {
    print('Battery: $battery%');
  }
}

void main() {
  Engine engine = Engine('Electric');

  ElectricCar car = ElectricCar('Tesla', engine, 90);

  car.showInfo();
  car.start();
  car.showBattery();
}
