module FPM_Filesystem
use FPM_Strings
use environment, only: get_os_type, OS_LINUX, OS_MACOS, OS_WINDOWS
implicit none

private
public :: number_of_rows, read_lines, list_files, exists, get_temp_filename

integer, parameter :: LINE_BUFFER_LEN = 1000

contains

integer function number_of_rows(s) result(nrows)
    ! determine number or rows
    integer,intent(in)::s
    integer :: ios
    character(len=100) :: r
    rewind(s)
    nrows = 0
    do
        read(s, *, iostat=ios) r
        if (ios /= 0) exit
        nrows = nrows + 1
    end do
    rewind(s)
end function


function read_lines(fh) result(lines)
    integer, intent(in) :: fh
    type(string_t), allocatable :: lines(:)

    integer :: i
    character(LINE_BUFFER_LEN) :: line_buffer

    allocate(lines(number_of_rows(fh)))
    do i = 1, size(lines)
        read(fh, '(A)') line_buffer
        lines(i)%s = trim(line_buffer)
    end do

end function read_lines


subroutine list_files(dir, files)
    character(len=*), intent(in) :: dir
    type(string_t), allocatable, intent(out) :: files(:)

    integer :: stat, fh
    character(:), allocatable :: temp_file

    ! Using `inquire` / exists on directories works with gfortran, but not ifort
    if (.not. exists(dir)) then
        allocate(files(0))
        return
    end if

    allocate(temp_file, source = get_temp_filename() )

    select case (get_os_type())
        case (OS_LINUX)
            call execute_command_line("ls " // dir // " > "//temp_file, exitstat=stat)
        case (OS_MACOS)
            call execute_command_line("ls " // dir // " > "//temp_file, exitstat=stat)
        case (OS_WINDOWS)
            call execute_command_line("dir /b " // dir // " > "//temp_file, exitstat=stat)
    end select
    if (stat /= 0) then
        print *, "execute_command_line() failed"
        error stop
    end if

    open(newunit=fh, file=temp_file, status="old")
    files = read_lines(fh)
    close(fh,status="delete")

end subroutine


logical function exists(filename) result(r)
    character(len=*), intent(in) :: filename
    inquire(file=filename, exist=r)
end function


function get_temp_filename() result(tempfile)
    ! Get a unused temporary filename
    !  Calls posix 'tempnam' - not recommended, but
    !   we have no security concerns for this application
    !   and use here is temporary.
    ! Works with MinGW
    !
    use iso_c_binding, only: c_ptr, C_NULL_PTR, c_f_pointer
    character(:), allocatable :: tempfile

    type(c_ptr) :: c_tempfile_ptr
    character(len=1), pointer :: c_tempfile(:)
    
    interface

        function c_tempnam(dir,pfx) result(tmp) BIND(C,name="tempnam")
            import
            type(c_ptr), intent(in), value :: dir
            type(c_ptr), intent(in), value :: pfx
            type(c_ptr) :: tmp
        end function c_tempnam

        subroutine c_free(ptr) BIND(C,name="free")
            import
            type(c_ptr), value :: ptr
        end subroutine c_free

    end interface

    c_tempfile_ptr = c_tempnam(C_NULL_PTR, C_NULL_PTR)
    call c_f_pointer(c_tempfile_ptr,c_tempfile,[LINE_BUFFER_LEN])

    tempfile = f_string(c_tempfile)

    call c_free(c_tempfile_ptr)

end function get_temp_filename


end module FPM_Filesystem