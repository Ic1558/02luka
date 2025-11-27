class Greeter:
    def __init__(self, name):
        self.name = name

    def say_hello(self):
        print(f"Hello, {self.name}!")

    def say_goodbye(self):
        print(f"Goodbye, {self.name}!")

if __name__ == "__main__":
    greeter = Greeter("World")
    greeter.say_hello()
    greeter.say_goodbye()
