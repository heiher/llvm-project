! Tests `-fno-analyzed-exprs-as-fortran` frontend option

!--------------------------
! RUN lines
!--------------------------
! RUN: %flang_fc1 -fdebug-unparse  %s | FileCheck %s --check-prefix=DEFAULT
! RUN: %flang_fc1 -fdebug-unparse -fno-analyzed-objects-for-unparse %s | FileCheck %s --check-prefix=DISABLED

! DEFAULT: PROGRAM TEST
! DEFAULT-NEXT:  REAL, PARAMETER :: val = 3.43e2_4
! DEFAULT-NEXT:  PRINT *, 3.47e2_4
! DEFAULT-NEXT: END PROGRAM

! DISABLED: PROGRAM TEST
! DISABLED-NEXT:  REAL, PARAMETER :: val = 343.0
! DISABLED-NEXT:  PRINT *, val+4
! DISABLED-NEXT: END PROGRAM

program test
  real, parameter :: val = 343.0
  print *, val + 4
end program
