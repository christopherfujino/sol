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
  variable alice = Student{id: 0, name: "Alice", classIds: Number[]};
  variable bob = Student{id: 1, name: "Bob", classIds: Number[]};
  variable calculus = Class{id: 0, name: "Calculus"};

  print("Hello " + bob.name + " and " + alice.name + "!");
}
