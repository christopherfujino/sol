structure Student {
  id Number;
  name String;
  classIds Number[];
}

structure Class {
  id Number;
  name String;
}

function main() {
  variable calculus = Class{id: 0, name: "Calculus"};
  variable alice = Student{id: 0, name: "Alice", classes: Class[]};
  variable bob = Student{id: 1, name: "Bob", classes: Class[calculus]};

  print("Hello " + bob.name + " and " + alice.name + "!");
  print(bob.name + " is enrolled in " + bob.classes[0].name);
}
