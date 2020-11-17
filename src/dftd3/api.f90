! This file is part of s-dftd3.
! SPDX-Identifier: LGPL-3.0-or-later
!
! s-dftd3 is free software: you can redistribute it and/or modify it under
! the terms of the GNU Lesser General Public License as published by
! the Free Software Foundation, either version 3 of the License, or
! (at your option) any later version.
!
! s-dftd3 is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU Lesser General Public License for more details.
!
! You should have received a copy of the GNU Lesser General Public License
! along with s-dftd3.  If not, see <https://www.gnu.org/licenses/>.

!> Definition of the public C-API of s-dftd3
!>
!>```c
!>{!./include/s-dftd3.h!}
!>```
module dftd3_api
   use iso_c_binding
   use mctc_env, only : wp, error_type, fatal_error
   use mctc_io_structure, only : structure_type, new
   use dftd3_cutoff, only : realspace_cutoff
   use dftd3_damping_mzero, only : mzero_damping_param, new_mzero_damping
   use dftd3_damping_rational, only : rational_damping_param, new_rational_damping
   use dftd3_damping_zero, only : zero_damping_param, new_zero_damping
   use dftd3_damping, only : damping_param
   use dftd3_disp, only : get_dispersion
   use dftd3_model, only : d3_model, new_d3_model
   use dftd3_param, only : d3_param, get_rational_damping, get_zero_damping, &
      & get_mrational_damping, get_mzero_damping
   use dftd3_version, only : get_dftd3_version
   implicit none
   private

   public :: get_version_api

   public :: vp_error
   public :: new_error_api, check_error_api, get_error_api, delete_error_api

   public :: vp_structure
   public :: new_structure_api, delete_structure_api, update_structure_api

   public :: vp_model
   public :: new_d3_model_api, delete_model_api

   public :: vp_param
   public :: new_zero_damping_api, load_zero_damping_api
   public :: new_rational_damping_api, load_rational_damping_api
   public :: new_mzero_damping_api, load_mzero_damping_api
   public :: new_mrational_damping_api, load_mrational_damping_api
   public :: delete_param_api


   !> Void pointer to error handle
   type :: vp_error
      !> Actual payload
      type(error_type), allocatable :: ptr
   end type vp_error

   !> Void pointer to molecular structure data
   type :: vp_structure
      !> Actual payload
      type(structure_type) :: ptr
   end type vp_structure

   !> Void pointer to dispersion model
   type :: vp_model
      !> Actual payload
      type(d3_model) :: ptr
   end type vp_model

   !> Void pointer to damping parameters
   type :: vp_param
      !> Actual payload
      class(damping_param), allocatable :: ptr
   end type vp_param


contains


!> Obtain library version as major * 10000 + minor + 100 + patch
function get_version_api() result(version) &
      & bind(C, name="dftd3_get_version")
   integer(c_int) :: version
   integer :: major, minor, patch

   call get_dftd3_version(major, minor, patch)
   version = 10000_c_int * major + 100_c_int * minor + patch

end function get_version_api


!> Create new error handle object
function new_error_api() &
      & result(verror) &
      & bind(C, name="dftd3_new_error")
   type(vp_error), pointer :: error
   type(c_ptr) :: verror

   allocate(error)
   verror = c_loc(error)

end function new_error_api


!> Delete error handle object
subroutine delete_error_api(verror) &
      & bind(C, name="dftd3_delete_error")
   type(c_ptr), intent(inout) :: verror
   type(vp_error), pointer :: error

   if (c_associated(verror)) then
      call c_f_pointer(verror, error)

      deallocate(error)
      verror = c_null_ptr
   end if

end subroutine delete_error_api


!> Check error handle status
function check_error_api(verror) result(status) &
      & bind(C, name="dftd3_check_error")
   type(c_ptr), value :: verror
   type(vp_error), pointer :: error
   integer(c_int) :: status

   if (c_associated(verror)) then
      call c_f_pointer(verror, error)

      if (allocated(error%ptr)) then
         status = 1
      else
         status = 0
      end if
   else
      status = 2
   end if

end function check_error_api


!> Get error message from error handle
subroutine get_error_api(verror, charptr, buffersize) &
      & bind(C, name="dftd3_get_error")
   type(c_ptr), value :: verror
   type(vp_error), pointer :: error
   character(kind=c_char), intent(inout) :: charptr(*)
   integer(c_int), intent(in), optional :: buffersize
   integer :: max_length

   if (c_associated(verror)) then
      call c_f_pointer(verror, error)

      if (present(buffersize)) then
         max_length = buffersize
      else
         max_length = huge(max_length) - 2
      end if

      if (allocated(error%ptr)) then
         call f_c_character(error%ptr%message, charptr, max_length)
      end if
   end if

end subroutine get_error_api


!> Create new molecular structure data (quantities in Bohr)
function new_structure_api(verror, natoms, numbers, positions, &
      & c_lattice, c_periodic) result(vmol) &
      & bind(C, name="dftd3_new_structure")
   type(c_ptr), value :: verror
   type(vp_error), pointer :: error
   integer(c_int), value, intent(in) :: natoms
   integer(c_int), intent(in) :: numbers(natoms)
   real(c_double), intent(in) :: positions(3, natoms)
   real(c_double), intent(in), optional :: c_lattice(3, 3)
   real(wp), allocatable :: lattice(:, :)
   logical(c_bool), intent(in), optional :: c_periodic(3)
   logical, allocatable :: periodic(:)
   type(vp_structure), pointer :: mol
   type(c_ptr) :: vmol

   vmol = c_null_ptr

   if (.not.c_associated(verror)) return
   call c_f_pointer(verror, error)

   if (present(c_lattice)) then
      allocate(lattice(3, 3))
      lattice(:, :) = c_lattice
   end if
   if (present(c_periodic)) then
      allocate(periodic(3))
      periodic(:) = c_periodic
   end if

   allocate(mol)
   call new(mol%ptr, numbers, positions, lattice=lattice, periodic=periodic)
   vmol = c_loc(mol)

end function new_structure_api


!> Delete molecular structure data
subroutine delete_structure_api(vmol) &
      & bind(C, name="dftd3_delete_structure")
   type(c_ptr), intent(inout) :: vmol
   type(vp_structure), pointer :: mol

   if (c_associated(vmol)) then
      call c_f_pointer(vmol, mol)

      deallocate(mol)
      vmol = c_null_ptr
   end if

end subroutine delete_structure_api


!> Update coordinates and lattice parameters (quantities in Bohr)
subroutine update_structure_api(verror, vmol, positions, lattice) &
      & bind(C, name="dftd3_update_structure")
   type(c_ptr), value :: verror
   type(vp_error), pointer :: error
   type(c_ptr), value :: vmol
   type(vp_structure), pointer :: mol
   real(c_double), intent(in) :: positions(3, *)
   real(c_double), intent(in), optional :: lattice(3, 3)

   if (.not.c_associated(verror)) then
      return
   end if
   call c_f_pointer(verror, error)

   if (.not.c_associated(vmol)) then
      call fatal_error(error%ptr, "Molecular structure data is missing")
      return
   end if
   call c_f_pointer(vmol, mol)

   if (mol%ptr%nat <= 0 .or. mol%ptr%nid <= 0 .or. .not.allocated(mol%ptr%num) &
      & .or. .not.allocated(mol%ptr%id) .or. .not.allocated(mol%ptr%xyz)) then
      call fatal_error(error%ptr, "Invalid molecular structure data provided")
      return
   end if

   mol%ptr%xyz(:, :) = positions(:3, :mol%ptr%nat)
   if (present(lattice)) then
      mol%ptr%lattice(:, :) = lattice(:3, :3)
   end if

end subroutine update_structure_api


!> Create new D3 dispersion model
function new_d3_model_api(verror, vmol) &
      & result(vdisp) &
      & bind(C, name="dftd3_new_d3_model")
   type(c_ptr), value :: verror
   type(vp_error), pointer :: error
   type(c_ptr), value :: vmol
   type(vp_structure), pointer :: mol
   type(c_ptr) :: vdisp
   type(vp_model), pointer :: disp

   vdisp = c_null_ptr

   if (.not.c_associated(verror)) return
   call c_f_pointer(verror, error)

   if (.not.c_associated(vmol)) then
      call fatal_error(error%ptr, "Molecular structure data is missing")
      return
   end if
   call c_f_pointer(vmol, mol)

   allocate(disp)
   call new_d3_model(disp%ptr, mol%ptr)
   vdisp = c_loc(disp)

end function new_d3_model_api


!> Delete dispersion model
subroutine delete_model_api(vdisp) &
      & bind(C, name="dftd3_delete_model")
   type(c_ptr), intent(inout) :: vdisp
   type(vp_model), pointer :: disp

   if (c_associated(vdisp)) then
      call c_f_pointer(vdisp, disp)

      deallocate(disp)
      vdisp = c_null_ptr
   end if

end subroutine delete_model_api


!> Create new rational damping parameters
function new_rational_damping_api(verror, vmol, s6, s8, s9, a1, a2, alp) &
      & result(vparam) &
      & bind(C, name="dftd3_new_rational_damping")
   type(c_ptr), value :: verror
   type(vp_error), pointer :: error
   type(c_ptr), value :: vmol
   type(vp_structure), pointer :: mol
   real(c_double), value, intent(in) :: s6
   real(c_double), value, intent(in) :: s8
   real(c_double), value, intent(in) :: s9
   real(c_double), value, intent(in) :: a1
   real(c_double), value, intent(in) :: a2
   real(c_double), value, intent(in) :: alp
   type(c_ptr) :: vparam
   type(rational_damping_param), allocatable :: tmp
   type(vp_param), pointer :: param

   vparam = c_null_ptr

   if (.not.c_associated(verror)) return
   call c_f_pointer(verror, error)

   if (.not.c_associated(vmol)) then
      call fatal_error(error%ptr, "Molecular structure data is missing")
      return
   end if
   call c_f_pointer(vmol, mol)

   allocate(tmp)
   call new_rational_damping(tmp, d3_param(s6=s6, s8=s8, s9=s9, a1=a1, a2=a2, &
      & alp=alp), mol%ptr%num)

   allocate(param)
   call move_alloc(tmp, param%ptr)
   vparam = c_loc(param)

end function new_rational_damping_api


!> Load rational damping parameters from internal storage
function load_rational_damping_api(verror, vmol, charptr, atm) &
      & result(vparam) &
      & bind(C, name="dftd3_load_rational_damping")
   type(c_ptr), value :: verror
   type(vp_error), pointer :: error
   type(c_ptr), value :: vmol
   type(vp_structure), pointer :: mol
   character(kind=c_char), intent(in) :: charptr(*)
   logical(c_bool), value, intent(in) :: atm
   character(len=:, kind=c_char), allocatable :: method
   type(c_ptr) :: vparam
   type(rational_damping_param), allocatable :: tmp
   type(vp_param), pointer :: param
   type(d3_param) :: inp
   real(wp), allocatable :: s9

   vparam = c_null_ptr

   if (.not.c_associated(verror)) return
   call c_f_pointer(verror, error)

   if (.not.c_associated(vmol)) then
      call fatal_error(error%ptr, "Molecular structure data is missing")
      return
   end if
   call c_f_pointer(vmol, mol)

   call c_f_character(charptr, method)

   if (atm) s9 = 1.0_wp
   call get_rational_damping(inp, method, error%ptr, s9)
   if (allocated(error%ptr)) return

   allocate(tmp)
   call new_rational_damping(tmp, inp, mol%ptr%num)

   allocate(param)
   call move_alloc(tmp, param%ptr)
   vparam = c_loc(param)

end function load_rational_damping_api


!> Create new zero damping parameters
function new_zero_damping_api(verror, vmol, s6, s8, s9, rs6, rs8, alp) &
      & result(vparam) &
      & bind(C, name="dftd3_new_zero_damping")
   type(c_ptr), value :: verror
   type(vp_error), pointer :: error
   type(c_ptr), value :: vmol
   type(vp_structure), pointer :: mol
   real(c_double), value, intent(in) :: s6
   real(c_double), value, intent(in) :: s8
   real(c_double), value, intent(in) :: s9
   real(c_double), value, intent(in) :: rs6
   real(c_double), value, intent(in) :: rs8
   real(c_double), value, intent(in) :: alp
   type(c_ptr) :: vparam
   type(zero_damping_param), allocatable :: tmp
   type(vp_param), pointer :: param

   vparam = c_null_ptr

   if (.not.c_associated(verror)) return
   call c_f_pointer(verror, error)

   if (.not.c_associated(vmol)) then
      call fatal_error(error%ptr, "Molecular structure data is missing")
      return
   end if
   call c_f_pointer(vmol, mol)

   allocate(tmp)
   call new_zero_damping(tmp, d3_param(s6=s6, s8=s8, s9=s9, rs6=rs6, rs8=rs8, &
      & alp=alp), mol%ptr%num)

   allocate(param)
   call move_alloc(tmp, param%ptr)
   vparam = c_loc(param)

end function new_zero_damping_api


!> Load zero damping parameters from internal storage
function load_zero_damping_api(verror, vmol, charptr, atm) &
      & result(vparam) &
      & bind(C, name="dftd3_load_zero_damping")
   type(c_ptr), value :: verror
   type(vp_error), pointer :: error
   type(c_ptr), value :: vmol
   type(vp_structure), pointer :: mol
   character(kind=c_char), intent(in) :: charptr(*)
   logical(c_bool), value, intent(in) :: atm
   character(len=:, kind=c_char), allocatable :: method
   type(c_ptr) :: vparam
   type(zero_damping_param), allocatable :: tmp
   type(vp_param), pointer :: param
   type(d3_param) :: inp
   real(wp), allocatable :: s9

   vparam = c_null_ptr

   if (.not.c_associated(verror)) return
   call c_f_pointer(verror, error)

   if (.not.c_associated(vmol)) then
      call fatal_error(error%ptr, "Molecular structure data is missing")
      return
   end if
   call c_f_pointer(vmol, mol)

   call c_f_character(charptr, method)

   if (atm) s9 = 1.0_wp
   call get_zero_damping(inp, method, error%ptr, s9)
   if (allocated(error%ptr)) return

   allocate(tmp)
   call new_zero_damping(tmp, inp, mol%ptr%num)

   allocate(param)
   call move_alloc(tmp, param%ptr)
   vparam = c_loc(param)

end function load_zero_damping_api


!> Create new rational damping parameters
function new_mrational_damping_api(verror, vmol, s6, s8, s9, a1, a2, alp) &
      & result(vparam) &
      & bind(C, name="dftd3_new_mrational_damping")
   type(c_ptr), value :: verror
   type(c_ptr), value :: vmol
   real(c_double), value, intent(in) :: s6
   real(c_double), value, intent(in) :: s8
   real(c_double), value, intent(in) :: s9
   real(c_double), value, intent(in) :: a1
   real(c_double), value, intent(in) :: a2
   real(c_double), value, intent(in) :: alp
   type(c_ptr) :: vparam

   vparam = new_rational_damping_api(verror, vmol, s6, s8, s9, a1, a2, alp)

end function new_mrational_damping_api


!> Load rational damping parameters from internal storage
function load_mrational_damping_api(verror, vmol, charptr, atm) &
      & result(vparam) &
      & bind(C, name="dftd3_load_mrational_damping")
   type(c_ptr), value :: verror
   type(vp_error), pointer :: error
   type(c_ptr), value :: vmol
   type(vp_structure), pointer :: mol
   character(kind=c_char), intent(in) :: charptr(*)
   logical(c_bool), value, intent(in) :: atm
   character(len=:, kind=c_char), allocatable :: method
   type(c_ptr) :: vparam
   type(rational_damping_param), allocatable :: tmp
   type(vp_param), pointer :: param
   type(d3_param) :: inp
   real(wp), allocatable :: s9

   vparam = c_null_ptr

   if (.not.c_associated(verror)) return
   call c_f_pointer(verror, error)

   if (.not.c_associated(vmol)) then
      call fatal_error(error%ptr, "Molecular structure data is missing")
      return
   end if
   call c_f_pointer(vmol, mol)

   call c_f_character(charptr, method)

   if (atm) s9 = 1.0_wp
   call get_mrational_damping(inp, method, error%ptr, s9)
   if (allocated(error%ptr)) return

   allocate(tmp)
   call new_rational_damping(tmp, inp, mol%ptr%num)

   allocate(param)
   call move_alloc(tmp, param%ptr)
   vparam = c_loc(param)

end function load_mrational_damping_api


!> Create new zero damping parameters
function new_mzero_damping_api(verror, vmol, s6, s8, s9, rs6, rs8, alp, bet) &
      & result(vparam) &
      & bind(C, name="dftd3_new_mzero_damping")
   type(c_ptr), value :: verror
   type(vp_error), pointer :: error
   type(c_ptr), value :: vmol
   type(vp_structure), pointer :: mol
   real(c_double), value, intent(in) :: s6
   real(c_double), value, intent(in) :: s8
   real(c_double), value, intent(in) :: s9
   real(c_double), value, intent(in) :: rs6
   real(c_double), value, intent(in) :: rs8
   real(c_double), value, intent(in) :: alp
   real(c_double), value, intent(in) :: bet
   type(c_ptr) :: vparam
   type(mzero_damping_param), allocatable :: tmp
   type(vp_param), pointer :: param

   vparam = c_null_ptr

   if (.not.c_associated(verror)) return
   call c_f_pointer(verror, error)

   if (.not.c_associated(vmol)) then
      call fatal_error(error%ptr, "Molecular structure data is missing")
      return
   end if
   call c_f_pointer(vmol, mol)

   allocate(tmp)
   call new_mzero_damping(tmp, d3_param(s6=s6, s8=s8, s9=s9, rs6=rs6, rs8=rs8, &
      & alp=alp, bet=bet), mol%ptr%num)

   allocate(param)
   call move_alloc(tmp, param%ptr)
   vparam = c_loc(param)

end function new_mzero_damping_api


!> Load zero damping parameters from internal storage
function load_mzero_damping_api(verror, vmol, charptr, atm) &
      & result(vparam) &
      & bind(C, name="dftd3_load_mzero_damping")
   type(c_ptr), value :: verror
   type(vp_error), pointer :: error
   type(c_ptr), value :: vmol
   type(vp_structure), pointer :: mol
   character(kind=c_char), intent(in) :: charptr(*)
   logical(c_bool), value, intent(in) :: atm
   character(len=:, kind=c_char), allocatable :: method
   type(c_ptr) :: vparam
   type(mzero_damping_param), allocatable :: tmp
   type(vp_param), pointer :: param
   type(d3_param) :: inp
   real(wp), allocatable :: s9

   vparam = c_null_ptr

   if (.not.c_associated(verror)) return
   call c_f_pointer(verror, error)

   if (.not.c_associated(vmol)) then
      call fatal_error(error%ptr, "Molecular structure data is missing")
      return
   end if
   call c_f_pointer(vmol, mol)

   call c_f_character(charptr, method)

   if (atm) s9 = 1.0_wp
   call get_mzero_damping(inp, method, error%ptr, s9)
   if (allocated(error%ptr)) return

   allocate(tmp)
   call new_mzero_damping(tmp, inp, mol%ptr%num)

   allocate(param)
   call move_alloc(tmp, param%ptr)
   vparam = c_loc(param)

end function load_mzero_damping_api


!> Delete damping parameters
subroutine delete_param_api(vparam) &
      & bind(C, name="dftd3_delete_param")
   type(c_ptr), intent(inout) :: vparam
   type(vp_param), pointer :: param

   if (c_associated(vparam)) then
      call c_f_pointer(vparam, param)

      deallocate(param)
      vparam = c_null_ptr
   end if

end subroutine delete_param_api


!> Calculate dispersion
subroutine get_dispersion_api(verror, vmol, vdisp, vparam, &
      & energy, c_gradient, c_sigma) &
      & bind(C, name="dftd3_get_dispersion")
   type(c_ptr), value :: verror
   type(vp_error), pointer :: error
   type(c_ptr), value :: vmol
   type(vp_structure), pointer :: mol
   type(c_ptr), value :: vdisp
   type(vp_model), pointer :: disp
   type(c_ptr), value :: vparam
   type(vp_param), pointer :: param
   real(c_double), intent(out) :: energy
   real(c_double), intent(out), optional :: c_gradient(3, *)
   real(wp), allocatable :: gradient(:, :)
   real(c_double), intent(out), optional :: c_sigma(3, 3)
   real(wp), allocatable :: sigma(:, :)

   if (.not.c_associated(verror)) return
   call c_f_pointer(verror, error)

   if (.not.c_associated(vmol)) then
      call fatal_error(error%ptr, "Molecular structure data is missing")
      return
   end if
   call c_f_pointer(vmol, mol)

   if (.not.c_associated(vdisp)) then
      call fatal_error(error%ptr, "Dispersion model is missing")
      return
   end if
   call c_f_pointer(vdisp, disp)

   if (.not.c_associated(vparam)) then
      call fatal_error(error%ptr, "Damping parameters are missing")
      return
   end if
   call c_f_pointer(vparam, param)

   if (.not.allocated(param%ptr)) then
      call fatal_error(error%ptr, "Damping parameters are not initialized")
      return
   end if

   if (present(c_gradient)) then
      gradient = c_gradient(:3, :mol%ptr%nat)
   endif

   if (present(c_gradient)) then
      sigma = c_sigma(:3, :3)
   endif

   call get_dispersion(mol%ptr, disp%ptr, param%ptr, realspace_cutoff(), &
      & energy, gradient, sigma)

   if (present(c_gradient)) then
      c_gradient(:3, :mol%ptr%nat) = gradient
   endif

   if (present(c_gradient)) then
      c_sigma(:3, :3) = sigma
   endif

end subroutine get_dispersion_api


subroutine f_c_character(rhs, lhs, len)
   character(kind=c_char), intent(out) :: lhs(*)
   character(len=*), intent(in) :: rhs
   integer, intent(in) :: len
   integer :: length
   length = min(len-1, len_trim(rhs))

   lhs(1:length) = transfer(rhs(1:length), lhs(1:length))
   lhs(length+1:length+1) = c_null_char

end subroutine f_c_character


subroutine c_f_character(rhs, lhs)
   character(kind=c_char), intent(in) :: rhs(*)
   character(len=:, kind=c_char), allocatable, intent(out) :: lhs

   integer :: ii

   do ii = 1, huge(ii) - 1
      if (rhs(ii) == c_null_char) then
         exit
      end if
   end do
   allocate(character(len=ii-1) :: lhs)
   lhs = transfer(rhs(1:ii-1), lhs)

end subroutine c_f_character


end module dftd3_api
