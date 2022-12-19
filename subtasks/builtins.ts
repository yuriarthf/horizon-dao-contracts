// import subtask to modify builtin hardhat tasks
import { subtask } from "hardhat/config";

// builtin tasks
import { TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS, TASK_TEST_GET_TEST_FILES } from "hardhat/builtin-tasks/task-names";

// substasks
subtask(TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS).setAction(async (_, __, runSuper) => {
  const paths = <string[]>await runSuper();

  return paths.filter((p) => !p.endsWith(".d.sol"));
});

subtask(TASK_TEST_GET_TEST_FILES).setAction(async (_, __, runSuper) => {
  const paths = <string[]>await runSuper();

  return paths.filter((p) => p.endsWith(".test.ts"));
});
