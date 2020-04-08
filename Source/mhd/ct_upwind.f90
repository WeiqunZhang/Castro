module ct_upwind

 use amrex_fort_module, only : rt => amrex_real
 use hlld_solver, only : hlld
 use meth_params_module

 implicit none 

 private primtocons
 public corner_transport
 
 
interface checkisnan
       module procedure checkisnanmult
       module procedure checkisnans
end interface checkisnan

 contains

subroutine corner_transport( q, qm, qp, q_l1 , q_l2 , q_l3 , q_h1 , q_h2 , q_h3, &      
                                flxx, flxx_l1 , flxx_l2 , flxx_l3 , flxx_h1 , flxx_h2 , flxx_h3, &
                                flxy, flxy_l1 , flxy_l2 , flxy_l3 , flxy_h1 , flxy_h2 , flxy_h3, &
                                flxz, flxz_l1 , flxz_l2 , flxz_l3 , flxz_h1 , flxz_h2 , flxz_h3, &
                                Ex, ex_l1,ex_l2,ex_l3,ex_h1,ex_h2,ex_h3, &
                                Ey, ey_l1,ey_l2,ey_l3,ey_h1,ey_h2,ey_h3, &
                                Ez, ez_l1,ez_l2,ez_l3,ez_h1,ez_h2,ez_h3, &
                                dx, dy, dz, dt)

 use amrex_fort_module, only : rt => amrex_real
 use meth_params_module, only : NQ
 use electric_field
implicit none

        integer, intent(in)   :: q_l1,q_l2,q_l3,q_h1,q_h2,q_h3

        integer, intent(in)   :: ex_l1,ex_l2,ex_l3,ex_h1,ex_h2,ex_h3
        integer, intent(in)   :: ey_l1,ey_l2,ey_l3,ey_h1,ey_h2,ey_h3
        integer, intent(in)   :: ez_l1,ez_l2,ez_l3,ez_h1,ez_h2,ez_h3

        integer, intent(in)   :: flxx_l1,flxx_l2,flxx_l3,flxx_h1,flxx_h2,flxx_h3
        integer, intent(in)   :: flxy_l1,flxy_l2,flxy_l3,flxy_h1,flxy_h2,flxy_h3
        integer, intent(in)   :: flxz_l1,flxz_l2,flxz_l3,flxz_h1,flxz_h2,flxz_h3

        real(rt), intent(in)  :: q(q_l1:q_h1,q_l2:q_h2,q_l3:q_h3,NQ) !prim vars at time t^n
        real(rt), intent(in)  :: qm(q_l1:q_h1,q_l2:q_h2,q_l3:q_h3,NQ,3)
        real(rt), intent(in)  :: qp(q_l1:q_h1,q_l2:q_h2,q_l3:q_h3,NQ,3)

        ! fluxes should be NVAR+3
        real(rt), intent(out) :: flxx(flxx_l1:flxx_h1,flxx_l2:flxx_h2,flxx_l3:flxx_h3,NVAR+3)   !Half Step Fluxes
        real(rt), intent(out) :: flxy(flxy_l1:flxy_h1,flxy_l2:flxy_h2,flxy_l3:flxy_h3,NVAR+3)   !Half Step Fluxes
        real(rt), intent(out) :: flxz(flxz_l1:flxz_h1,flxz_l2:flxz_h2,flxz_l3:flxz_h3,NVAR+3)   !Half Step Fluxes

        real(rt), intent(out)  :: Ex(ex_l1:ex_h1,ex_l2:ex_h2,ex_l3:ex_h3)
        real(rt), intent(out)  :: Ey(ey_l1:ey_h1,ey_l2:ey_h2,ey_l3:ey_h3)
        real(rt), intent(out)  :: Ez(ez_l1:ez_h1,ez_l2:ez_h2,ez_l3:ez_h3)
 
        ! these are conserved + magnetic field (cell centered)
 ! TODO: should be NVAR+3
        real(rt)  :: um(q_l1:q_h1,q_l2:q_h2,q_l3:q_h3,NVAR+3,3) !PtoC Vars
        real(rt)  :: up(q_l1:q_h1,q_l2:q_h2,q_l3:q_h3,NVAR+3,3)
        real(rt)  :: cons_temp_M(q_l1:q_h1,q_l2:q_h2,q_l3:q_h3,NVAR+3,3,2) !2D Temporary Conservative Vars
        real(rt)  :: cons_temp_P(q_l1:q_h1,q_l2:q_h2,q_l3:q_h3,NVAR+3,3,2) !2D Temporary Conservative Vars
        real(rt)  :: cons_half_M(q_l1:q_h1,q_l2:q_h2,q_l3:q_h3,NVAR+3,3) !Flux Corrected Conservative Vars
        real(rt)  :: cons_half_P(q_l1:q_h1,q_l2:q_h2,q_l3:q_h3,NVAR+3,3)

        real(rt)  :: q_temp_M(q_l1:q_h1,q_l2:q_h2,q_l3:q_h3,NQ,3,2) !2D Temporary Primitive Vars
        real(rt)  :: q_temp_P(q_l1:q_h1,q_l2:q_h2,q_l3:q_h3,NQ,3,2) !2D Temporary Primitive Vars
        real(rt)  :: q_half_M(q_l1:q_h1,q_l2:q_h2,q_l3:q_h3,NQ,3) !Flux Corrected Primitive Vars
        real(rt)  :: q_half_P(q_l1:q_h1,q_l2:q_h2,q_l3:q_h3,NQ,3) !Flux Corrected Primitive Vars


        real(rt)  :: flxx1D(flxx_l1:flxx_h1,flxx_l2:flxx_h2,flxx_l3:flxx_h3,NVAR+3)
        real(rt)  :: flxy1D(flxy_l1:flxy_h1,flxy_l2:flxy_h2,flxy_l3:flxy_h3,NVAR+3) 
    real(rt)  :: flxz1D(flxz_l1:flxz_h1,flxz_l2:flxz_h2,flxz_l3:flxz_h3,NVAR+3) !Flux1d for all directions

        real(rt)  :: flxx2D(flxx_l1:flxx_h1,flxx_l2:flxx_h2,flxx_l3:flxx_h3,NVAR+3, 2) !Flux2d for all directions 2 perpendicular directions
        real(rt)  :: flxy2D(flxy_l1:flxy_h1,flxy_l2:flxy_h2,flxy_l3:flxy_h3,NVAR+3, 2) !Flux2d for all directions 2 perpendicular directions
        real(rt)  :: flxz2D(flxz_l1:flxz_h1,flxz_l2:flxz_h2,flxz_l3:flxz_h3,NVAR+3, 2) !Flux2d for all directions 2 perpendicular directions

        real(rt)  :: q2D(q_l1:q_h1,q_l2:q_h2,q_l3:q_h3,NQ)
        real(rt)  :: dx, dy, dz, dt

        integer  :: i, work_lo(3), work_hi(3)


um = 0.d0
up = 0.d0
cons_temp_M = 0.d0
cons_temp_P = 0.d0
q_temp_M = 0.d0
q_temp_P = 0.d0
cons_half_M = 0.d0
cons_half_P = 0.d0
q_half_M = 0.d0
q_half_P = 0.d0
q2D = 0.d0

flxx1D = 0.d0
flxy1D = 0.d0
flxz1D = 0.d0

flxx2D = 0.d0
flxy2D = 0.d0
flxz2D = 0.d0

Ex = 0.d0
Ey = 0.d0
Ez = 0.d0

!Calculate Flux 1D
        !x-dir
        work_lo(1) = flxx_l1
        work_lo(2) = flxx_l2
        work_lo(3) = flxx_l3
        work_hi(1) = flxx_h1
        work_hi(2) = flxx_h2
        work_hi(3) = flxx_h3
        
        call hlld(work_lo, work_hi, qm,qp,q_l1,q_l2,q_l3,q_h1,q_h2,q_h3, &
                  flxx1D(:,:,:,:),flxx_l1,flxx_l2,flxx_l3,flxx_h1,flxx_h2,flxx_h3, 1)



        work_lo(1) = flxy_l1
        work_lo(2) = flxy_l2
        work_lo(3) = flxy_l3
        work_hi(1) = flxy_h1
        work_hi(2) = flxy_h2
        work_hi(3) = flxy_h3

        !y-dir  
        call hlld(work_lo, work_hi, qm,qp,q_l1,q_l2,q_l3,q_h1,q_h2,q_h3, &
                  flxy1D(:,:,:,:),flxy_l1,flxy_l2,flxy_l3,flxy_h1,flxy_h2,flxy_h3, 2)



        work_lo(1) = flxz_l1
        work_lo(2) = flxz_l2
        work_lo(3) = flxz_l3
        work_hi(1) = flxz_h1
        work_hi(2) = flxz_h2
        work_hi(3) = flxz_h3
                  
        !z-dir
        call hlld(work_lo, work_hi, qm,qp,q_l1,q_l2,q_l3,q_h1,q_h2,q_h3,&
                  flxz1D(:,:,:,:),flxz_l1,flxz_l2,flxz_l3,flxz_h1,flxz_h2,flxz_h3, 3)


!Prim to Cons
do i = 1,3
        call PrimToCons(qm(:,:,:,:,i), um(:,:,:,:,i), q_l1 , q_l2 , q_l3 , q_h1 , q_h2 , q_h3)
        call PrimToCons(qp(:,:,:,:,i), up(:,:,:,:,i), q_l1 , q_l2 , q_l3 , q_h1 , q_h2 , q_h3)
enddo


!Use "1D" fluxes To interpolate Temporary Edge Centered Electric Fields


        work_lo(1) = ex_l1+1
        work_lo(2) = ex_l2+1
        work_lo(3) = ex_l3+1
        work_hi(1) = ex_h1-1
        work_hi(2) = ex_h2-1
        work_hi(3) = ex_h3-1
        call electric_edge_x(work_lo, work_hi, &
                             q, q_l1,q_l2,q_l3,q_h1,q_h2,q_h3, &
                             Ex, ex_l1,ex_l2,ex_l3,ex_h1,ex_h2,ex_h3, &
                             flxy1D, flxy_l1,flxy_l2,flxy_l3,flxy_h1,flxy_h2,flxy_h3, &
                             flxz1D, flxz_l1,flxz_l2,flxz_l3,flxz_h1,flxz_h2,flxz_h3)

        work_lo(1) = ey_l1+1
        work_lo(2) = ey_l2+1
        work_lo(3) = ey_l3+1
        work_hi(1) = ey_h1-1
        work_hi(2) = ey_h2-1
        work_hi(3) = ey_h3-1
        call electric_edge_y(work_lo, work_hi, &
                             q, q_l1,q_l2,q_l3,q_h1,q_h2,q_h3, &
                             Ey, ey_l1,ey_l2,ey_l3,ey_h1,ey_h2,ey_h3, &
                             flxx1D, flxx_l1,flxx_l2,flxx_l3,flxx_h1,flxx_h2,flxx_h3, &
                             flxz1D, flxz_l1,flxz_l2,flxz_l3,flxz_h1,flxz_h2,flxz_h3)

        work_lo(1) = ez_l1+1
        work_lo(2) = ez_l2+1
        work_lo(3) = ez_l3+1
        work_hi(1) = ez_h1-1
        work_hi(2) = ez_h2-1
        work_hi(3) = ez_h3-1
        call electric_edge_z(work_lo, work_hi, &
                             q, q_l1,q_l2,q_l3,q_h1,q_h2,q_h3, &
                             Ez, ez_l1,ez_l2,ez_l3,ez_h1,ez_h2,ez_h3, &
                             flxx1D, flxx_l1,flxx_l2,flxx_l3,flxx_h1,flxx_h2,flxx_h3, &
                             flxy1D, flxy_l1,flxy_l2,flxy_l3,flxy_h1,flxy_h2,flxy_h3)

!Corner Couple
        
        work_lo(1) = q_l1+1
        work_lo(2) = q_l2+1
        work_lo(3) = q_l3+1
        work_hi(1) = q_h1-1
        work_hi(2) = q_h2-1
        work_hi(3) = q_h3-1
        
        call corner_couple(work_lo, work_hi, &
                           cons_temp_M, cons_temp_P, um, up, q_l1,q_l2,q_l3,q_h1,q_h2,q_h3,&
                           flxx1D, flxx_l1,flxx_l2,flxx_l3,flxx_h1,flxx_h2,flxx_h3, &
                           flxy1D, flxy_l1,flxy_l2,flxy_l3,flxy_h1,flxy_h2,flxy_h3, &
                           flxz1D, flxz_l1,flxz_l2,flxz_l3,flxz_h1,flxz_h2,flxz_h3, &
                           dx, dy, dz, dt) !Correct Conservative vars using Transverse Fluxes

        call corner_couple_mag(work_lo, work_hi, &
                               cons_temp_M, cons_temp_P, um, up, q_l1,q_l2,q_l3,q_h1,q_h2,q_h3,&
                               Ex, ex_l1,ex_l2,ex_l3,ex_h1,ex_h2,ex_h3, &
                               Ey, ey_l1,ey_l2,ey_l3,ey_h1,ey_h2,ey_h3, &
                               Ez, ez_l1,ez_l2,ez_l3,ez_h1,ez_h2,ez_h3, &
                               dx, dy, dz, dt) !Correct Conservative vars using Transverse Fluxes


!Cons To Prim
do i = 1,3
        call ConsToPrim(q_temp_M(:,:,:,:,i,1), cons_temp_M(:,:,:,:,i,1), q_l1 , q_l2 , q_l3 , q_h1 , q_h2 , q_h3)
        call ConsToPrim(q_temp_P(:,:,:,:,i,1), cons_temp_P(:,:,:,:,i,1), q_l1 , q_l2 , q_l3 , q_h1 , q_h2 , q_h3)
        call ConsToPrim(q_temp_M(:,:,:,:,i,2), cons_temp_M(:,:,:,:,i,2), q_l1 , q_l2 , q_l3 , q_h1 , q_h2 , q_h3)
        call ConsToPrim(q_temp_P(:,:,:,:,i,2), cons_temp_P(:,:,:,:,i,2), q_l1 , q_l2 , q_l3 , q_h1 , q_h2 , q_h3)
enddo

!Calculate Flux 2D
do i = 1,2
        work_lo(1) = flxx_l1+1
        work_lo(2) = flxx_l2+1
        work_lo(3) = flxx_l3+1
        work_hi(1) = flxx_h1-1
        work_hi(2) = flxx_h2-1
        work_hi(3) = flxx_h3-1
        !x-dir
        call hlld(work_lo, work_hi, q_temp_M(:,:,:,:,:,i),q_temp_P(:,:,:,:,:,i),q_l1,q_l2,q_l3,q_h1,q_h2,q_h3, &
                  flxx2D(:,:,:,:,i),flxx_l1,flxx_l2,flxx_l3,flxx_h1,flxx_h2,flxx_h3, 1)

        !y-dir  
        work_lo(1) = flxy_l1+1
        work_lo(2) = flxy_l2+1
        work_lo(3) = flxy_l3+1
        work_hi(1) = flxy_h1-1
        work_hi(2) = flxy_h2-1
        work_hi(3) = flxy_h3-1

        call hlld(work_lo, work_hi, q_temp_M(:,:,:,:,:,i),q_temp_P(:,:,:,:,:,i),q_l1,q_l2,q_l3,q_h1,q_h2,q_h3, &
                  flxy2D(:,:,:,:,i),flxy_l1,flxy_l2,flxy_l3,flxy_h1,flxy_h2,flxy_h3, 2)

        !z-dir

        work_lo(1) = flxz_l1+1
        work_lo(2) = flxz_l2+1
        work_lo(3) = flxz_l3+1
        work_hi(1) = flxz_h1-1
        work_hi(2) = flxz_h2-1
        work_hi(3) = flxz_h3-1
        
        call hlld(work_lo, work_hi, q_temp_M(:,:,:,:,:,i),q_temp_P(:,:,:,:,:,i),q_l1,q_l2,q_l3,q_h1,q_h2,q_h3,&
                  flxz2D(:,:,:,:,i),flxz_l1,flxz_l2,flxz_l3,flxz_h1,flxz_h2,flxz_h3, 3)

enddo

!Use Averaged 2D fluxes to interpolate temporary Edge Centered Electric Fields, reuse "flx1D"
        flxx1D(:,:,:,:) = 0.5d0*(flxx2D(:,:,:,:,1) + flxx2D(:,:,:,:,2))
        flxy1D(:,:,:,:) = 0.5d0*(flxy2D(:,:,:,:,1) + flxy2D(:,:,:,:,2))
        flxz1D(:,:,:,:) = 0.5d0*(flxz2D(:,:,:,:,1) + flxz2D(:,:,:,:,2))


        work_lo(1) = ex_l1+1!+2
        work_lo(2) = ex_l2+1!+2
        work_lo(3) = ex_l3+1!+2
        work_hi(1) = ex_h1-1!-2
        work_hi(2) = ex_h2-1!-2
        work_hi(3) = ex_h3-1!-2
        call electric_edge_x(work_lo, work_hi, &
                         q, q_l1,q_l2,q_l3,q_h1,q_h2,q_h3, &
                             Ex, ex_l1,ex_l2,ex_l3,ex_h1,ex_h2,ex_h3, &
                             flxy1D, flxy_l1,flxy_l2,flxy_l3,flxy_h1,flxy_h2,flxy_h3, &
                             flxz1D, flxz_l1,flxz_l2,flxz_l3,flxz_h1,flxz_h2,flxz_h3)

        work_lo(1) = ey_l1+1!+2
        work_lo(2) = ey_l2+1!+2
        work_lo(3) = ey_l3+1!+2
        work_hi(1) = ey_h1-1!-2
        work_hi(2) = ey_h2-1!-2
        work_hi(3) = ey_h3-1!-2
        call electric_edge_y(work_lo, work_hi, &
                         q, q_l1,q_l2,q_l3,q_h1,q_h2,q_h3, &
                             Ey, ey_l1,ey_l2,ey_l3,ey_h1,ey_h2,ey_h3, &
                             flxx1D, flxx_l1,flxx_l2,flxx_l3,flxx_h1,flxx_h2,flxx_h3, &
                             flxz1D, flxz_l1,flxz_l2,flxz_l3,flxz_h1,flxz_h2,flxz_h3)

        work_lo(1) = ez_l1+1!+2
        work_lo(2) = ez_l2+1!+2
        work_lo(3) = ez_l3+1!+2
        work_hi(1) = ez_h1-1!-2
        work_hi(2) = ez_h2-1!-2
        work_hi(3) = ez_h3-1!-2
        call electric_edge_z(work_lo, work_hi, &
                         q, q_l1,q_l2,q_l3,q_h1,q_h2,q_h3, &
                             Ez, ez_l1,ez_l2,ez_l3,ez_h1,ez_h2,ez_h3, &
                             flxx1D, flxx_l1,flxx_l2,flxx_l3,flxx_h1,flxx_h2,flxx_h3, &
                             flxy1D, flxy_l1,flxy_l2,flxy_l3,flxy_h1,flxy_h2,flxy_h3)

!Half Step conservative vars
        work_lo(1) = q_l1+1
        work_lo(2) = q_l2+1
        work_lo(3) = q_l3+1
        work_hi(1) = q_h1-2
        work_hi(2) = q_h2-2
        work_hi(3) = q_h3-2
                                        
        call half_step(work_lo, work_hi, &
                       cons_half_M, cons_half_P, um, up, q_l1,q_l2,q_l3,q_h1,q_h2,q_h3,&
                       flxx2D, flxx_l1,flxx_l2,flxx_l3,flxx_h1,flxx_h2,flxx_h3, &
                       flxy2D, flxy_l1,flxy_l2,flxy_l3,flxy_h1,flxy_h2,flxy_h3, &
                       flxz2D, flxz_l1,flxz_l2,flxz_l3,flxz_h1,flxz_h2,flxz_h3, &
                       dx, dy, dz, dt)

        call half_step_mag(work_lo, work_hi, &
                                           cons_half_M, cons_half_P, um, up, q_l1,q_l2,q_l3,q_h1,q_h2,q_h3,&
                           Ex, ex_l1,ex_l2,ex_l3,ex_h1,ex_h2,ex_h3, &
                                           Ey, ey_l1,ey_l2,ey_l3,ey_h1,ey_h2,ey_h3, &
                                           Ez, ez_l1,ez_l2,ez_l3,ez_h1,ez_h2,ez_h3, &
                                           dx, dy, dz, dt)
do i = 1,3
        call ConsToPrim(q_half_M(:,:,:,:,i), cons_half_M(:,:,:,:,i), q_l1 , q_l2 , q_l3 , q_h1 , q_h2 , q_h3)
        call ConsToPrim(q_half_P(:,:,:,:,i), cons_half_P(:,:,:,:,i), q_l1 , q_l2 , q_l3 , q_h1 , q_h2 , q_h3)
enddo

!Final Fluxes


        !x-dir
        work_lo(1) = flxx_l1+2
        work_lo(2) = flxx_l2+2
        work_lo(3) = flxx_l3+2
        work_hi(1) = flxx_h1-2
        work_hi(2) = flxx_h2-2
        work_hi(3) = flxx_h3-2

        call hlld(work_lo, work_hi, q_half_M,q_half_P,q_l1,q_l2,q_l3,q_h1,q_h2,q_h3, &
                   flxx,flxx_l1,flxx_l2,flxx_l3,flxx_h1,flxx_h2,flxx_h3, 1)

        !y-dir  
        work_lo(1) = flxy_l1+2
        work_lo(2) = flxy_l2+2
        work_lo(3) = flxy_l3+2
        work_hi(1) = flxy_h1-2
        work_hi(2) = flxy_h2-2
        work_hi(3) = flxy_h3-2
        
        call hlld(work_lo, work_hi, q_half_M,q_half_P,q_l1,q_l2,q_l3,q_h1,q_h2,q_h3, &
                   flxy,flxy_l1,flxy_l2,flxy_l3,flxy_h1,flxy_h2,flxy_h3, 2)

        !z-dir
        work_lo(1) = flxz_l1+2
        work_lo(2) = flxz_l2+2
        work_lo(3) = flxz_l3+2
        work_hi(1) = flxz_h1-2
        work_hi(2) = flxz_h2-2
        work_hi(3) = flxz_h3-2
        
        call hlld(work_lo, work_hi, q_half_M,q_half_P,q_l1,q_l2,q_l3,q_h1,q_h2,q_h3,&
                  flxz,flxz_l1,flxz_l2,flxz_l3,flxz_h1,flxz_h2,flxz_h3, 3)
        
!Primitive update
       call prim_half(q2D,q,q_l1,q_l2,q_l3,q_h1,q_h2,q_h3, &
                      flxx1D, flxx_l1,flxx_l2,flxx_l3,flxx_h1,flxx_h2,flxx_h3, &
                      flxy1D, flxy_l1,flxy_l2,flxy_l3,flxy_h1,flxy_h2,flxy_h3, &
                      flxz1D, flxz_l1,flxz_l2,flxz_l3,flxz_h1,flxz_h2,flxz_h3, &
                      dx, dy, dz, dt)

!Final Electric Field Update


        work_lo(1) = ex_l1+2!+3
        work_lo(2) = ex_l2+2!+3
        work_lo(3) = ex_l3+2!+3
        work_hi(1) = ex_h1-2!-3
        work_hi(2) = ex_h2-2!-3
        work_hi(3) = ex_h3-2!-3
        call electric_edge_x(work_lo, work_hi, &
                         q2D, q_l1,q_l2,q_l3,q_h1,q_h2,q_h3, &
                                             Ex, ex_l1,ex_l2,ex_l3,ex_h1,ex_h2,ex_h3, &
                                             flxy, flxy_l1,flxy_l2,flxy_l3,flxy_h1,flxy_h2,flxy_h3, &
                                             flxz, flxz_l1,flxz_l2,flxz_l3,flxz_h1,flxz_h2,flxz_h3)

        work_lo(1) = ey_l1+2!+3
        work_lo(2) = ey_l2+2!+3
        work_lo(3) = ey_l3+2!+3
        work_hi(1) = ey_h1-2!-3
        work_hi(2) = ey_h2-2!-3
        work_hi(3) = ey_h3-2!-3
        call electric_edge_y(work_lo, work_hi, &
                         q2D, q_l1,q_l2,q_l3,q_h1,q_h2,q_h3, &
                                             Ey, ey_l1,ey_l2,ey_l3,ey_h1,ey_h2,ey_h3, &
                                             flxx, flxx_l1,flxx_l2,flxx_l3,flxx_h1,flxx_h2,flxx_h3, &
                                             flxz, flxz_l1,flxz_l2,flxz_l3,flxz_h1,flxz_h2,flxz_h3)

        work_lo(1) = ez_l1+2!+3
        work_lo(2) = ez_l2+2!+3
        work_lo(3) = ez_l3+2!+3
        work_hi(1) = ez_h1-2!-3
        work_hi(2) = ez_h2-2!-3
        work_hi(3) = ez_h3-2!-3
        call electric_edge_z(work_lo, work_hi, &
                         q2D, q_l1,q_l2,q_l3,q_h1,q_h2,q_h3, &
                                             Ez, ez_l1,ez_l2,ez_l3,ez_h1,ez_h2,ez_h3, &
                                             flxx, flxx_l1,flxx_l2,flxx_l3,flxx_h1,flxx_h2,flxx_h3, &
                                             flxy, flxy_l1,flxy_l2,flxy_l3,flxy_h1,flxy_h2,flxy_h3)

end subroutine corner_transport

!================================================= Calculate the Conservative Variables ===============================================

subroutine PrimToCons(q, u, q_l1 ,q_l2 ,q_l3 ,q_h1 ,q_h2 ,q_h3)

 use amrex_fort_module, only : rt => amrex_real
 use meth_params_module
 use eos_type_module, only : eos_t, eos_input_rp
 use eos_module, only: eos
 use network, only: nspec

implicit none

        integer, intent(in)             ::q_l1,q_l2,q_l3,q_h1,q_h2, q_h3
        real(rt), intent(in)    ::q(q_l1:q_h1,q_l2:q_h2,q_l3:q_h3,NQ)
        real(rt), intent(out)   ::u(q_l1:q_h1,q_l2:q_h2,q_l3:q_h3,NVAR+3)
        integer                                 :: i ,j ,k

  type(eos_t) :: eos_state        

 do k = q_l3,q_h3
    do j = q_l2,q_h2
       do i = q_l1, q_h1
          u(i,j,k,URHO)  = q(i,j,k,QRHO)
          u(i,j,k,UMX)    = q(i,j,k,QRHO)*q(i,j,k,QU)
          u(i,j,k,UMY)    = q(i,j,k,QRHO)*q(i,j,k,QV)
          u(i,j,k,UMZ)    = q(i,j,k,QRHO)*q(i,j,k,QW)
  
          eos_state % rho = q(i, j, k, QRHO)
          eos_state % p   = q(i, j, k, QPRES)
          eos_state % T   = 100.d0 !dummy initial g.  
          eos_state % xn  = q(i, j, k, QFS:QFS+nspec-1)

          call eos(eos_input_rp, eos_state)

          u(i,j,k,UEDEN) = eos_state % rho * eos_state % e &
               + 0.5d0*q(i,j,k,QRHO)*dot_product(q(i,j,k,QU:QW),q(i,j,k,QU:QW)) &
               + 0.5d0*(dot_product(q(i,j,k,QMAGX:QMAGZ),q(i,j,k,QMAGX:QMAGZ)))

          u(i,j,k,UEINT) = eos_state % rho * eos_state % e

          u(i,j,k,NVAR+1:NVAR+3) = q(i,j,k,QMAGX:QMAGZ)

          ! species
          u(i,j,k,UFS:UFS-1+nspec) = q(i,j,k,QRHO) * q(i,j,k,QFS:QFS-1+nspec)

       enddo
    enddo
 enddo
end subroutine PrimToCons

!================================================= Calculate the Primitve Variables ===============================================

subroutine ConsToPrim(q, u, q_l1 ,q_l2 ,q_l3 ,q_h1 ,q_h2 ,q_h3)

 use amrex_fort_module, only : rt => amrex_real
 use meth_params_module
 use eos_module, only : eos
 use eos_type_module, only : eos_t, eos_input_re
 use network, only : nspec

 implicit none

 integer, intent(in)            ::q_l1,q_l2,q_l3,q_h1,q_h2, q_h3
 real(rt), intent(in)   ::u(q_l1:q_h1,q_l2:q_h2,q_l3:q_h3,NVAR+3)
 real(rt), intent(out)  ::q(q_l1:q_h1,q_l2:q_h2,q_l3:q_h3,NQ)
 integer                                        :: i ,j ,k
 integer                :: UMAGX, UMAGZ

 type (eos_t) :: eos_state

 UMAGX = NVAR+1
 UMAGZ = NVAR+3
 !q = u
 do k = q_l3,q_h3
    do j = q_l2,q_h2
       do i = q_l1, q_h1
          q(i,j,k,QRHO)  = u(i,j,k,URHO)
          q(i,j,k,QU)    = u(i,j,k,UMX)/q(i,j,k,QRHO)
          q(i,j,k,QV)    = u(i,j,k,UMY)/q(i,j,k,QRHO)
          q(i,j,k,QW)    = u(i,j,k,UMZ)/q(i,j,k,QRHO)
          q(i,j,k,QREINT) = u(i,j,k,UEDEN) - 0.5d0*q(i,j,k,QRHO)*dot_product(q(i,j,k,QU:QW),q(i,j,k,QU:QW)) &
               - 0.5d0*dot_product(u(i,j,k,UMAGX:UMAGZ), u(i,j,k,UMAGX:UMAGZ)) !NVAR+1->UMAGX

          ! species
          q(i,j,k,QFS:QFS-1+nspec) = u(i,j,k,UFS:UFS-1+nspec)/u(i,j,k,URHO)

          eos_state % rho = q(i, j, k, QRHO)
          eos_state % e   = q(i, j, k, QREINT)/eos_state % rho 
          eos_state % xn  = q(i, j, k, QFS:QFS+nspec-1)
          eos_state % T   = 100.d0  ! initial guess

          call eos(eos_input_re, eos_state)

          q(i,j,k,QTEMP) = eos_state % T
          q(i,j,k,QPRES) = eos_state % p
          q(i,j,k,QMAGX:QMAGZ) = u(i,j,k,UMAGX:UMAGZ)
       enddo
    enddo
 enddo
end subroutine ConsToPrim

!======================================= Update the Temporary Conservative Variables with Transverse 1D Fluxes ========================
subroutine corner_couple(lo, hi, &
                         uL, uR, um, up, q_l1,q_l2,q_l3,q_h1,q_h2,q_h3,&
                         flxx, flxx_l1,flxx_l2,flxx_l3,flxx_h1,flxx_h2,flxx_h3, &
                         flxy, flxy_l1,flxy_l2,flxy_l3,flxy_h1,flxy_h2,flxy_h3, &
                         flxz, flxz_l1,flxz_l2,flxz_l3,flxz_h1,flxz_h2,flxz_h3, &
                         dx, dy, dz, dt)

use amrex_fort_module, only : rt => amrex_real
use meth_params_module
use network, only : nspec

implicit none
        
        integer, intent(in)             :: lo(3), hi(3)
        integer, intent(in)             :: q_l1,q_l2,q_l3,q_h1,q_h2, q_h3
        integer, intent(in)             :: flxx_l1,flxx_l2,flxx_l3,flxx_h1,flxx_h2,flxx_h3
        integer, intent(in)             :: flxy_l1,flxy_l2,flxy_l3,flxy_h1,flxy_h2,flxy_h3
        integer, intent(in)             :: flxz_l1,flxz_l2,flxz_l3,flxz_h1,flxz_h2,flxz_h3
        
        real(rt), intent(in)    ::um(q_l1:q_h1,q_l2:q_h2,q_l3:q_h3,NVAR+3,3)
        real(rt), intent(in)    ::up(q_l1:q_h1,q_l2:q_h2,q_l3:q_h3,NVAR+3,3)

        real(rt), intent(out) :: flxx(flxx_l1:flxx_h1,flxx_l2:flxx_h2,flxx_l3:flxx_h3,NVAR+3)
        real(rt), intent(out) :: flxy(flxy_l1:flxy_h1,flxy_l2:flxy_h2,flxy_l3:flxy_h3,NVAR+3)
        real(rt), intent(out) :: flxz(flxz_l1:flxz_h1,flxz_l2:flxz_h2,flxz_l3:flxz_h3,NVAR+3)

        real(rt), intent(out)   ::uL(q_l1:q_h1,q_l2:q_h2,q_l3:q_h3,NVAR+3,3,2)
        real(rt), intent(out)   ::uR(q_l1:q_h1,q_l2:q_h2,q_l3:q_h3,NVAR+3,3,2)

        real(rt)                                :: dx, dy, dz, dt, u, v, w
        integer                                 :: i ,j ,k
        

        uL(:,:,:,:,:,1) = um
        uL(:,:,:,:,:,2) = um
        uR(:,:,:,:,:,1) = up
        uR(:,:,:,:,:,2) = up

    do k = lo(3), hi(3)
       do j = lo(2), hi(2)
          do i = lo(1), hi(1)
        !Left Corrected States
             uL(i,j,k,URHO,1,1) = um(i,j,k,URHO,1) - dt/(3.d0*dx)*(flxy(i,j+1,k,URHO) - flxy(i,j,k,URHO))! y corrected x
             uL(i,j,k,UMX,1,1) = um(i,j,k,UMX,1) - dt/(3.d0*dx)*(flxy(i,j+1,k,UMX) - flxy(i,j,k,UMX))
             uL(i,j,k,UMY,1,1) = um(i,j,k,UMY,1) - dt/(3.d0*dx)*(flxy(i,j+1,k,UMY) - flxy(i,j,k,UMY))
             uL(i,j,k,UMZ,1,1) = um(i,j,k,UMZ,1) - dt/(3.d0*dx)*(flxy(i,j+1,k,UMZ) - flxy(i,j,k,UMZ))
             uL(i,j,k,UEDEN,1,1) = um(i,j,k,UEDEN,1) - dt/(3.d0*dx)*(flxy(i,j+1,k,UEDEN) - flxy(i,j,k,UEDEN))
             uL(i,j,k,UFS:UFS+nspec-1,1,1) = um(i,j,k,UFS:UFS+nspec-1,1) - dt/(3.d0*dx)*(flxy(i,j+1,k,UFS:UFS+nspec-1) &  
                                             - flxy(i,j,k,UFS:UFS+nspec-1))

             uL(i,j,k,URHO,1,2) = um(i,j,k,URHO,1) - dt/(3.d0*dx)*(flxz(i,j,k+1,URHO) - flxz(i,j,k,URHO))! z corrected x
             uL(i,j,k,UMX,1,2) = um(i,j,k,UMX,1) - dt/(3.d0*dx)*(flxz(i,j,k+1,UMX) - flxz(i,j,k,UMX))
             uL(i,j,k,UMY,1,2) = um(i,j,k,UMY,1) - dt/(3.d0*dx)*(flxz(i,j,k+1,UMY) - flxz(i,j,k,UMY))
             uL(i,j,k,UMZ,1,2) = um(i,j,k,UMZ,1) - dt/(3.d0*dx)*(flxz(i,j,k+1,UMZ) - flxz(i,j,k,UMZ))
             uL(i,j,k,UEDEN,1,2) = um(i,j,k,UEDEN,1) - dt/(3.d0*dx)*(flxz(i,j,k+1,UEDEN) - flxz(i,j,k,UEDEN))
             uL(i,j,k,UFS:UFS+nspec-1,1,2) = um(i,j,k,UFS:UFS+nspec-1,1) - dt/(3.d0*dx)*(flxz(i,j,k+1,UFS:UFS+nspec-1) &
                                             - flxz(i,j,k,UFS:UFS+nspec-1))

             uL(i,j,k,URHO,2,1) = um(i,j,k,URHO,2) - dt/(3.d0*dy)*(flxx(i+1,j,k,URHO) - flxx(i,j,k,URHO))! x corrected y
             uL(i,j,k,UMX,2,1) = um(i,j,k,UMX,2) - dt/(3.d0*dy)*(flxx(i+1,j,k,UMX) - flxx(i,j,k,UMX))
             uL(i,j,k,UMY,2,1) = um(i,j,k,UMY,2) - dt/(3.d0*dy)*(flxx(i+1,j,k,UMY) - flxx(i,j,k,UMY))
             uL(i,j,k,UMZ,2,1) = um(i,j,k,UMZ,2) - dt/(3.d0*dy)*(flxx(i+1,j,k,UMZ) - flxx(i,j,k,UMZ))
             uL(i,j,k,UEDEN,2,1) = um(i,j,k,UEDEN,2) - dt/(3.d0*dy)*(flxx(i+1,j,k,UEDEN) - flxx(i,j,k,UEDEN))
             uL(i,j,k,UFS:UFS+nspec-1,2,1) = um(i,j,k,UFS:UFS+nspec-1,2) - dt/(3.d0*dy)*(flxx(i+1,j,k,UFS:UFS+nspec-1) &
                                             - flxx(i,j,k,UFS:UFS+nspec-1))

             uL(i,j,k,URHO,2,2) = um(i,j,k,URHO,2) - dt/(3.d0*dy)*(flxz(i,j,k+1,URHO) - flxz(i,j,k,URHO))! z corrected y
             uL(i,j,k,UMX,2,2) = um(i,j,k,UMX,2) - dt/(3.d0*dy)*(flxz(i,j,k+1,UMX) - flxz(i,j,k,UMX))
             uL(i,j,k,UMY,2,2) = um(i,j,k,UMY,2) - dt/(3.d0*dy)*(flxz(i,j,k+1,UMY) - flxz(i,j,k,UMY))
             uL(i,j,k,UMZ,2,2) = um(i,j,k,UMZ,2) - dt/(3.d0*dy)*(flxz(i,j,k+1,UMZ) - flxz(i,j,k,UMZ))
             uL(i,j,k,UEDEN,2,2) = um(i,j,k,UEDEN,2) - dt/(3.d0*dy)*(flxz(i,j,k+1,UEDEN) - flxz(i,j,k,UEDEN))
             uL(i,j,k,UFS:UFS+nspec-1,2,2) = um(i,j,k,UFS:UFS+nspec-1,2) - dt/(3.d0*dy)*(flxz(i,j,k+1,UFS:UFS+nspec-1) & 
                                             - flxz(i,j,k,UFS:UFS+nspec-1))

             uL(i,j,k,URHO,3,1) = um(i,j,k,URHO,3) - dt/(3.d0*dz)*(flxx(i+1,j,k,URHO) - flxx(i,j,k,URHO))! x corrected z
             uL(i,j,k,UMX,3,1) = um(i,j,k,UMX,3) - dt/(3.d0*dz)*(flxx(i+1,j,k,UMX) - flxx(i,j,k,UMX))
             uL(i,j,k,UMY,3,1) = um(i,j,k,UMY,3) - dt/(3.d0*dz)*(flxx(i+1,j,k,UMY) - flxx(i,j,k,UMY))
             uL(i,j,k,UMZ,3,1) = um(i,j,k,UMZ,3) - dt/(3.d0*dz)*(flxx(i+1,j,k,UMZ) - flxx(i,j,k,UMZ))
             uL(i,j,k,UEDEN,3,1) = um(i,j,k,UEDEN,3) - dt/(3.d0*dz)*(flxx(i+1,j,k,UEDEN) - flxx(i,j,k,UEDEN))
             uL(i,j,k,UFS:UFS+nspec-1,3,1) = um(i,j,k,UFS:UFS+nspec-1,3) - dt/(3.d0*dz)*(flxx(i+1,j,k,UFS:UFS+nspec-1) &
                                            - flxx(i,j,k,UFS:UFS+nspec-1))

             uL(i,j,k,URHO,3,2) = um(i,j,k,URHO,3) - dt/(3.d0*dz)*(flxy(i,j+1,k,URHO) - flxy(i,j,k,URHO))! y corrected z
             uL(i,j,k,UMX,3,2) = um(i,j,k,UMX,3) - dt/(3.d0*dz)*(flxy(i,j+1,k,UMX) - flxy(i,j,k,UMX))
             uL(i,j,k,UMY,3,2) = um(i,j,k,UMY,3) - dt/(3.d0*dz)*(flxy(i,j+1,k,UMY) - flxy(i,j,k,UMY))
             uL(i,j,k,UMZ,3,2) = um(i,j,k,UMZ,3) - dt/(3.d0*dz)*(flxy(i,j+1,k,UMZ) - flxy(i,j,k,UMZ))
             uL(i,j,k,UEDEN,3,2) = um(i,j,k,UEDEN,3) - dt/(3.d0*dz)*(flxy(i,j+1,k,UEDEN) - flxy(i,j,k,UEDEN))
             uL(i,j,k,UFS:UFS+nspec-1,3,2) = um(i,j,k,UFS:UFS+nspec-1,3) - dt/(3.d0*dz)*(flxy(i,j+1,k,UFS:UFS+nspec-1) &
                                            - flxy(i,j,k,UFS:UFS+nspec-1))

                                !if(i.eq. 4 .and.j.eq. 16 .and.k.eq. 1) then 
                                !       print*, "Corner Couple" 
                                !       print*, i, j, k
                                !       print*, "UL y corrected x  =", uL(i,j,k,URHO:UEDEN,1,1)
                                !       print*, "um = ",  um(i,j,k,:,1)
                                !       print*, "flxy i, j+1/2, k = ", flxy(i,j+1,k,:) 
                                !       print*, "flxy, i, j-1/2,k = ", flxy(i,j,k,:)
                                !       pause
                                !endif

                                u = uL(i,j,k,UMX,1,1)/uL(i,j,k,URHO,1,1)
                                v = uL(i,j,k,UMY,1,1)/uL(i,j,k,URHO,1,1)
                                w = uL(i,j,k,UMZ,1,1)/uL(i,j,k,URHO,1,1)
                                uL(i,j,k,UEINT,1,1) = uL(i,j,k,UEDEN,1,1) - 0.5d0*uL(i,j,k,URHO,1,1)*(u**2 + v**2 + w**2)

                                u = uL(i,j,k,UMX,1,2)/uL(i,j,k,URHO,1,2)
                                v = uL(i,j,k,UMY,1,2)/uL(i,j,k,URHO,1,2)
                                w = uL(i,j,k,UMZ,1,2)/uL(i,j,k,URHO,1,2)
                                uL(i,j,k,UEINT,1,2) = uL(i,j,k,UEDEN,1,2) - 0.5d0*uL(i,j,k,URHO,1,2)*(u**2 + v**2 + w**2)
                        
                                u = uL(i,j,k,UMX,2,1)/uL(i,j,k,URHO,2,1)
                                v = uL(i,j,k,UMY,2,1)/uL(i,j,k,URHO,2,1)
                                w = uL(i,j,k,UMZ,2,1)/uL(i,j,k,URHO,2,1)
                                uL(i,j,k,UEINT,2,1) = uL(i,j,k,UEDEN,2,1) - 0.5d0*uL(i,j,k,URHO,2,1)*(u**2 + v**2 + w**2)

                                u = uL(i,j,k,UMX,2,2)/uL(i,j,k,URHO,2,2)
                                v = uL(i,j,k,UMY,2,2)/uL(i,j,k,URHO,2,2)
                                w = uL(i,j,k,UMZ,2,2)/uL(i,j,k,URHO,2,2)
                                uL(i,j,k,UEINT,2,2) = uL(i,j,k,UEDEN,2,2) - 0.5d0*uL(i,j,k,URHO,2,2)*(u**2 + v**2 + w**2)

                                u = uL(i,j,k,UMX,3,1)/uL(i,j,k,URHO,3,1)
                                v = uL(i,j,k,UMY,3,1)/uL(i,j,k,URHO,3,1)
                                w = uL(i,j,k,UMZ,3,1)/uL(i,j,k,URHO,3,1)
                                uL(i,j,k,UEINT,3,1) = uL(i,j,k,UEDEN,3,1) - 0.5d0*uL(i,j,k,URHO,3,1)*(u**2 + v**2 + w**2)

                                u = uL(i,j,k,UMX,3,2)/uL(i,j,k,URHO,3,2)
                                v = uL(i,j,k,UMY,3,2)/uL(i,j,k,URHO,3,2)
                                w = uL(i,j,k,UMZ,3,2)/uL(i,j,k,URHO,3,2)
                                uL(i,j,k,UEINT,3,2) = uL(i,j,k,UEDEN,3,2) - 0.5d0*uL(i,j,k,URHO,3,2)*(u**2 + v**2 + w**2)


        !Right Corrected States
             uR(i,j,k,URHO,1,1) = up(i,j,k,URHO,1) - dt/(3.d0*dx)*(flxy(i,j+1,k,URHO) - flxy(i,j,k,URHO))
             uR(i,j,k,UMX,1,1) = up(i,j,k,UMX,1) - dt/(3.d0*dx)*(flxy(i,j+1,k,UMX) - flxy(i,j,k,UMX))
             uR(i,j,k,UMY,1,1) = up(i,j,k,UMY,1) - dt/(3.d0*dx)*(flxy(i,j+1,k,UMY) - flxy(i,j,k,UMY))
             uR(i,j,k,UMZ,1,1) = up(i,j,k,UMZ,1) - dt/(3.d0*dx)*(flxy(i,j+1,k,UMZ) - flxy(i,j,k,UMZ))
             uR(i,j,k,UEDEN,1,1) = up(i,j,k,UEDEN,1) - dt/(3.d0*dx)*(flxy(i,j+1,k,UEDEN) - flxy(i,j,k,UEDEN))
             uR(i,j,k,UFS:UFS+nspec-1,1,1) = up(i,j,k,UFS:UFS+nspec-1,1) - dt/(3.d0*dx)*(flxy(i,j+1,k,UFS:UFS+nspec-1) & 
                                             - flxy(i,j,k,UFS:UFS+nspec-1))

             uR(i,j,k,URHO,1,2) = up(i,j,k,URHO,1) - dt/(3.d0*dx)*(flxz(i,j,k+1,URHO) - flxz(i,j,k,URHO))
             uR(i,j,k,UMX,1,2) = up(i,j,k,UMX,1) - dt/(3.d0*dx)*(flxz(i,j,k+1,UMX) - flxz(i,j,k,UMX))
             uR(i,j,k,UMY,1,2) = up(i,j,k,UMY,1) - dt/(3.d0*dx)*(flxz(i,j,k+1,UMY) - flxz(i,j,k,UMY))
             uR(i,j,k,UMZ,1,2) = up(i,j,k,UMZ,1) - dt/(3.d0*dx)*(flxz(i,j,k+1,UMZ) - flxz(i,j,k,UMZ))
             uR(i,j,k,UEDEN,1,2) = up(i,j,k,UEDEN,1) - dt/(3.d0*dx)*(flxz(i,j,k+1,UEDEN) - flxz(i,j,k,UEDEN))
             uR(i,j,k,UFS:UFS+nspec-1,1,2) = up(i,j,k,UFS:UFS+nspec-1,1) - dt/(3.d0*dx)*(flxz(i,j,k+1,UFS:UFS+nspec-1) & 
                                            - flxz(i,j,k,UFS:UFS+nspec-1))

             uR(i,j,k,URHO,2,1) = up(i,j,k,URHO,2) - dt/(3.d0*dy)*(flxx(i+1,j,k,URHO) - flxx(i,j,k,URHO))
             uR(i,j,k,UMX,2,1) = up(i,j,k,UMX,2) - dt/(3.d0*dy)*(flxx(i+1,j,k,UMX) - flxx(i,j,k,UMX))
             uR(i,j,k,UMY,2,1) = up(i,j,k,UMY,2) - dt/(3.d0*dy)*(flxx(i+1,j,k,UMY) - flxx(i,j,k,UMY))
             uR(i,j,k,UMZ,2,1) = up(i,j,k,UMZ,2) - dt/(3.d0*dy)*(flxx(i+1,j,k,UMZ) - flxx(i,j,k,UMZ))
             uR(i,j,k,UEDEN,2,1) = up(i,j,k,UEDEN,2) - dt/(3.d0*dy)*(flxx(i+1,j,k,UEDEN) - flxx(i,j,k,UEDEN))
             uR(i,j,k,UFS:UFS+nspec-1,2,1) = up(i,j,k,UFS:UFS+nspec-1,2) - dt/(3.d0*dy)*(flxx(i+1,j,k,UFS:UFS+nspec-1) & 
                                            - flxx(i,j,k,UFS:UFS+nspec-1))

             uR(i,j,k,URHO,2,2) = up(i,j,k,URHO,2) - dt/(3.d0*dy)*(flxz(i,j,k+1,URHO) - flxz(i,j,k,URHO))
             uR(i,j,k,UMX,2,2) = up(i,j,k,UMX,2) - dt/(3.d0*dy)*(flxz(i,j,k+1,UMX) - flxz(i,j,k,UMX))
             uR(i,j,k,UMY,2,2) = up(i,j,k,UMY,2) - dt/(3.d0*dy)*(flxz(i,j,k+1,UMY) - flxz(i,j,k,UMY))
             uR(i,j,k,UMZ,2,2) = up(i,j,k,UMZ,2) - dt/(3.d0*dy)*(flxz(i,j,k+1,UMZ) - flxz(i,j,k,UMZ))
             uR(i,j,k,UEDEN,2,2) = up(i,j,k,UEDEN,2) - dt/(3.d0*dy)*(flxz(i,j,k+1,UEDEN) - flxz(i,j,k,UEDEN))
             uR(i,j,k,UFS:UFS+nspec-1,2,2) = up(i,j,k,UFS:UFS+nspec-1,2) - dt/(3.d0*dy)*(flxz(i,j,k+1,UFS:UFS+nspec-1) & 
                                             - flxz(i,j,k,UFS:UFS+nspec-1))

             uR(i,j,k,URHO,3,1) = up(i,j,k,URHO,3) - dt/(3.d0*dz)*(flxx(i+1,j,k,URHO) - flxx(i,j,k,URHO))
             uR(i,j,k,UMX,3,1) = up(i,j,k,UMX,3) - dt/(3.d0*dz)*(flxx(i+1,j,k,UMX) - flxx(i,j,k,UMX))
             uR(i,j,k,UMY,3,1) = up(i,j,k,UMY,3) - dt/(3.d0*dz)*(flxx(i+1,j,k,UMY) - flxx(i,j,k,UMY))
             uR(i,j,k,UMZ,3,1) = up(i,j,k,UMZ,3) - dt/(3.d0*dz)*(flxx(i+1,j,k,UMZ) - flxx(i,j,k,UMZ))
             uR(i,j,k,UEDEN,3,1) = up(i,j,k,UEDEN,3) - dt/(3.d0*dz)*(flxx(i+1,j,k,UEDEN) - flxx(i,j,k,UEDEN))
             uR(i,j,k,UFS:UFS+nspec-1,3,1) = up(i,j,k,UFS:UFS+nspec-1,3) - dt/(3.d0*dz)*(flxx(i+1,j,k,UFS:UFS+nspec-1) &
                                             - flxx(i,j,k,UFS:UFS+nspec-1))

             uR(i,j,k,URHO,3,2) = up(i,j,k,URHO,3) - dt/(3.d0*dz)*(flxy(i,j+1,k,URHO) - flxy(i,j,k,URHO))
             uR(i,j,k,UMX,3,2) = up(i,j,k,UMX,3) - dt/(3.d0*dz)*(flxy(i,j+1,k,UMX) - flxy(i,j,k,UMX))
             uR(i,j,k,UMY,3,2) = up(i,j,k,UMY,3) - dt/(3.d0*dz)*(flxy(i,j+1,k,UMY) - flxy(i,j,k,UMY))
             uR(i,j,k,UMZ,3,2) = up(i,j,k,UMZ,3) - dt/(3.d0*dz)*(flxy(i,j+1,k,UMZ) - flxy(i,j,k,UMZ))
             uR(i,j,k,UEDEN,3,2) = up(i,j,k,UEDEN,3) - dt/(3.d0*dz)*(flxy(i,j+1,k,UEDEN) - flxy(i,j,k,UEDEN))
             uR(i,j,k,UFS:UFS+nspec-1,3,2) = up(i,j,k,UFS:UFS+nspec-1,3) - dt/(3.d0*dz)*(flxy(i,j+1,k,UFS:UFS+nspec-1) &
                                             - flxy(i,j,k,UFS:UFS+nspec-1))

                                
                                u = uR(i,j,k,UMX,1,1)/uR(i,j,k,URHO,1,1)
                                v = uR(i,j,k,UMY,1,1)/uR(i,j,k,URHO,1,1)
                                w = uR(i,j,k,UMZ,1,1)/uR(i,j,k,URHO,1,1)
                                uR(i,j,k,UEINT,1,1) = uR(i,j,k,UEDEN,1,1) - 0.5d0*uR(i,j,k,URHO,1,1)*(u**2 + v**2 + w**2)

                                u = uR(i,j,k,UMX,1,2)/uR(i,j,k,URHO,1,2)
                                v = uR(i,j,k,UMY,1,2)/uR(i,j,k,URHO,1,2)
                                w = uR(i,j,k,UMZ,1,2)/uR(i,j,k,URHO,1,2)
                                uR(i,j,k,UEINT,1,2) = uR(i,j,k,UEDEN,1,2) - 0.5d0*uR(i,j,k,URHO,1,2)*(u**2 + v**2 + w**2)
                        
                                u = uR(i,j,k,UMX,2,1)/uR(i,j,k,URHO,2,1)
                                v = uR(i,j,k,UMY,2,1)/uR(i,j,k,URHO,2,1)
                                w = uR(i,j,k,UMZ,2,1)/uR(i,j,k,URHO,2,1)
                                uR(i,j,k,UEINT,2,1) = uR(i,j,k,UEDEN,2,1) - 0.5d0*uR(i,j,k,URHO,2,1)*(u**2 + v**2 + w**2)

                                u = uR(i,j,k,UMX,2,2)/uR(i,j,k,URHO,2,2)
                                v = uR(i,j,k,UMY,2,2)/uR(i,j,k,URHO,2,2)
                                w = uR(i,j,k,UMZ,2,2)/uR(i,j,k,URHO,2,2)
                                uR(i,j,k,UEINT,2,2) = uR(i,j,k,UEDEN,2,2) - 0.5d0*uR(i,j,k,URHO,2,2)*(u**2 + v**2 + w**2)

                                u = uR(i,j,k,UMX,3,1)/uR(i,j,k,URHO,3,1)
                                v = uR(i,j,k,UMY,3,1)/uR(i,j,k,URHO,3,1)
                                w = uR(i,j,k,UMZ,3,1)/uR(i,j,k,URHO,3,1)
                                uR(i,j,k,UEINT,3,1) = uR(i,j,k,UEDEN,3,1) - 0.5d0*uR(i,j,k,URHO,3,1)*(u**2 + v**2 + w**2)

                                u = uR(i,j,k,UMX,3,2)/uR(i,j,k,URHO,3,2)
                                v = uR(i,j,k,UMY,3,2)/uR(i,j,k,URHO,3,2)
                                w = uR(i,j,k,UMZ,3,2)/uR(i,j,k,URHO,3,2)
                                uR(i,j,k,UEINT,3,2) = uR(i,j,k,UEDEN,3,2) - 0.5d0*uR(i,j,k,URHO,3,2)*(u**2 + v**2 + w**2)

                        enddo
                enddo
        enddo
end subroutine corner_couple

!================================== Use 1D Electric Fields to Transverse correct the Temporary Magnetic Fields ===========================
subroutine corner_couple_mag(lo, hi, &
                             uL, uR, um, up, q_l1,q_l2,q_l3,q_h1,q_h2,q_h3, &
                                                     Ex, ex_l1,ex_l2,ex_l3,ex_h1,ex_h2,ex_h3, &
                                             Ey, ey_l1,ey_l2,ey_l3,ey_h1,ey_h2,ey_h3, &
                                         Ez, ez_l1,ez_l2,ez_l3,ez_h1,ez_h2,ez_h3, &
                             dx, dy, dz, dt)
use amrex_fort_module, only : rt => amrex_real
use meth_params_module, only : NVAR, UEINT

!Correction using Faraday's Law
implicit none

        integer, intent(in)     :: lo(3), hi(3)
        integer, intent(in)     :: q_l1,q_l2,q_l3,q_h1,q_h2, q_h3
        integer, intent(in)     :: ex_l1,ex_l2,ex_l3,ex_h1,ex_h2, ex_h3
        integer, intent(in)     :: ey_l1,ey_l2,ey_l3,ey_h1,ey_h2, ey_h3
        integer, intent(in)     :: ez_l1,ez_l2,ez_l3,ez_h1,ez_h2, ez_h3
        real(rt), intent(inout) :: uL(q_l1:q_h1,q_l2:q_h2,q_l3:q_h3,NVAR+3,3,2)
        real(rt), intent(inout) :: uR(q_l1:q_h1,q_l2:q_h2,q_l3:q_h3,NVAR+3,3,2)
        real(rt), intent(in)    :: um(q_l1:q_h1,q_l2:q_h2,q_l3:q_h3,NVAR+3,3)
        real(rt), intent(in)    :: up(q_l1:q_h1,q_l2:q_h2,q_l3:q_h3,NVAR+3,3)   

        real(rt), intent(in)    :: Ex(ex_l1:ex_h1,ex_l2:ex_h2,ex_l3:ex_h3)
        real(rt), intent(in)    :: Ey(ey_l1:ey_h1,ey_l2:ey_h2,ey_l3:ey_h3)
        real(rt), intent(in)    :: Ez(ez_l1:ez_h1,ez_l2:ez_h2,ez_l3:ez_h3)

        real(rt)                :: dx, dy, dz, dt
        integer                 :: i ,j ,k
        integer                 ::UMAGX, UMAGY, UMAGZ

        UMAGX = NVAR+1
        UMAGY = NVAR+2
        UMAGZ = NVAR+3

        do k = lo(3), hi(3)
                do j = lo(2), hi(2)
                        do i = lo(1), hi(1)
                !Left State
                                !X-direction 
                                !-> Affected by Y flux
                                uL(i,j,k,UMAGX,1,1) = um(i,j,k,UMAGX,1) + dt/(3.d0*dx)*(Ez(i,j+1,k) - Ez(i,j,k))
                                uL(i,j,k,UMAGZ,1,1) = um(i,j,k,UMAGZ,1) + dt/(6.d0*dx)* &
                                                                                ((Ex(i,j+1,k+1) - Ex(i,j,k+1)) + &
                                                                                 (Ex(i,j+1,k  ) - Ex(i,j,k)))
                                !-> Affected by Z flux
                                uL(i,j,k,UMAGX,1,2) = um(i,j,k,UMAGX,1) - dt/(3.d0*dx)*(Ey(i,j,k+1) - Ey(i,j,k))
                                uL(i,j,k,UMAGY,1,2) = um(i,j,k,UMAGY,1) - dt/(6.d0*dx)*&
                                                                                ((Ex(i,j+1,k+1) - Ex(i,j+1,k)) + &
                                                                                 (Ex(i,j  ,k+1) - Ex(i,j  ,k)))
                                !-> Affected by X flux
                                uL(i,j,k,UMAGY,1,1) = um(i,j,k,UMAGY,1)
                                uL(i,j,k,UMAGZ,1,2) = um(i,j,k,UMAGZ,1)

                                !Y-direction
                                !-> Affected by X flux
                                uL(i,j,k,UMAGY,2,1) = um(i,j,k,UMAGY,2) - dt/(3.d0*dy)*(Ez(i+1,j,k) - Ez(i,j,k))
                                uL(i,j,k,UMAGZ,2,1) = um(i,j,k,UMAGZ,2) - dt/(6.d0*dy)*&
                                                                        ((Ey(i+1,j,k+1) - Ey(i,j,k+1)) + &
                                                                         (Ey(i+1,j,k  ) - Ey(i,j,k  )))
                                !-> Affected by Z flux
                                uL(i,j,k,UMAGY,2,2) = um(i,j,k,UMAGY,2) + dt/(3.d0*dy)*(Ex(i,j,k+1) - Ex(i,j,k))
                                uL(i,j,k,UMAGX,2,2) = um(i,j,k,UMAGX,2) + dt/(6.d0*dy)*&
                                                                        ((Ey(i+1,j,k+1) - Ey(i+1,j,k)) + &
                                                                         (Ey(i  ,j,k+1) - Ey(i  ,j,k)))

                                uL(i,j,k,UMAGX,2,1) = um(i,j,k,UMAGX,2)
                                uL(i,j,k,UMAGZ,2,2) = um(i,j,k,UMAGZ,2)

                                !Z-Direction
                                !-> Affected by X flux
                                uL(i,j,k,UMAGZ,3,1) = um(i,j,k,UMAGZ,3) + dt/(3.d0*dz)*(Ey(i+1,j,k) - Ey(i,j,k))
                                uL(i,j,k,UMAGY,3,1) = um(i,j,k,UMAGY,3) + dt/(6.d0*dz)*&
                                                                        ((Ez(i+1,j+1,k) - Ez(i,j+1,k)) + &
                                                                         (Ez(i+1,j  ,k) - Ez(i,j  ,k)))
                                !-> Affected by Y flux
                                uL(i,j,k,UMAGZ,3,2) = um(i,j,k,UMAGZ,3) - dt/(3.d0*dz)*(Ex(i,j+1,k) - Ex(i,j,k))
                                uL(i,j,k,UMAGX,3,2) = um(i,j,k,UMAGX,3) - dt/(6.d0*dz)*&
                                                                        ((Ez(i+1,j+1,k) - Ez(i+1,j,k)) + &
                                                                         (Ez(i  ,j+1,k) - Ez(i  ,j,k)))

                                uL(i,j,k,UMAGX,3,1) = um(i,j,k,UMAGX,3)
                                uL(i,j,k,UMAGY,3,2) = um(i,j,k,UMAGY,3)

                                uL(i,j,k,UEINT,1,1) = uL(i,j,k,UEINT,1,1) -0.5d0*dot_product(uL(i,j,k,UMAGX:UMAGZ,1,1),uL(i,j,k,UMAGX:UMAGZ,1,1))

                                uL(i,j,k,UEINT,1,2) = uL(i,j,k,UEINT,1,2) -0.5d0*dot_product(uL(i,j,k,UMAGX:UMAGZ,1,2),uL(i,j,k,UMAGX:UMAGZ,1,2))

                                uL(i,j,k,UEINT,2,1) = uL(i,j,k,UEINT,2,1) -0.5d0*dot_product(uL(i,j,k,UMAGX:UMAGZ,2,1),uL(i,j,k,UMAGX:UMAGZ,2,1))

                                uL(i,j,k,UEINT,2,2) = uL(i,j,k,UEINT,2,2) -0.5d0*dot_product(uL(i,j,k,UMAGX:UMAGZ,2,2),uL(i,j,k,UMAGX:UMAGZ,2,2))

                                uL(i,j,k,UEINT,3,1) = uL(i,j,k,UEINT,3,1) -0.5d0*dot_product(uL(i,j,k,UMAGX:UMAGZ,3,1),uL(i,j,k,UMAGX:UMAGZ,3,1))

                                uL(i,j,k,UEINT,3,2) = uL(i,j,k,UEINT,3,2) -0.5d0*dot_product(uL(i,j,k,UMAGX:UMAGZ,3,2),uL(i,j,k,UMAGX:UMAGZ,3,2))
                !Right State
                                !X-direction 
                                !-> Affected by Y flux
                                uR(i,j,k,UMAGX,1,1) = up(i,j,k,UMAGX,1) + dt/(3.d0*dx)*(Ez(i+1,j+1,k) - Ez(i+1,j,k))
                                uR(i,j,k,UMAGZ,1,1) = up(i,j,k,UMAGZ,1) + dt/(6.d0*dx)*&
                                                                                ((Ex(i,j+1,k+1) - Ex(i,j,k+1)) + &
                                                                                 (Ex(i,j+1,k  ) - Ex(i,j,k  )))
                                !-> Affected by Z flux
                                uR(i,j,k,UMAGX,1,2) = up(i,j,k,UMAGX,1) - dt/(3.d0*dx)*(Ey(i+1,j,k+1) - Ey(i+1,j,k))
                                uR(i,j,k,UMAGY,1,2) = up(i,j,k,UMAGY,1) - dt/(6.d0*dx)*&
                                                                                ((Ex(i,j+1,k+1) - Ex(i,j+1,k)) + &
                                                                                 (Ex(i,j  ,k+1) - Ex(i,j  ,k)))

                                uR(i,j,k,UMAGY,1,1) = up(i,j,k,UMAGY,1)
                                uR(i,j,k,UMAGZ,1,2) = up(i,j,k,UMAGZ,1)
                                !Y-direction
                                !-> Affected by X flux
                                uR(i,j,k,UMAGY,2,1) = up(i,j,k,UMAGY,2) - dt/(3.d0*dy)*(Ez(i+1,j+1,k) - Ez(i,j+1,k))
                                uR(i,j,k,UMAGZ,2,1) = up(i,j,k,UMAGZ,2) - dt/(6.d0*dy)*&
                                                                        ((Ey(i+1,j,k+1) - Ey(i,j,k+1)) + &
                                                                         (Ey(i+1,j,k  ) - Ey(i,j,k  )))
                                !-> Affected by Z flux
                                uR(i,j,k,UMAGY,2,2) = up(i,j,k,UMAGY,2) + dt/(3.d0*dy)*(Ex(i,j+1,k+1) - Ex(i,j+1,k))
                                uR(i,j,k,UMAGX,2,2) = up(i,j,k,UMAGX,2) + dt/(6.d0*dy)*&
                                                                        ((Ey(i+1,j,k+1) - Ey(i+1,j,k)) + &
                                                                         (Ey(i  ,j,k+1) - Ey(i  ,j,k)))

                                uR(i,j,k,UMAGX,2,1) = up(i,j,k,UMAGX,2)
                                uR(i,j,k,UMAGZ,2,2) = up(i,j,k,UMAGZ,2)

                                !Z-Direction
                                !-> Affected by X flux
                                uR(i,j,k,UMAGZ,3,1) = up(i,j,k,UMAGZ,3) + dt/(3.d0*dz)*(Ey(i+1,j,k+1) - Ey(i,j,k+1))
                                uR(i,j,k,UMAGY,3,1) = up(i,j,k,UMAGY,3) + dt/(6.d0*dz)*&
                                                                        ((Ez(i+1,j+1,k) - Ez(i,j+1,k)) + &
                                                                         (Ez(i+1,j  ,k) - Ez(i,j  ,k)))
                                !-> Affected by Y flux
                                uR(i,j,k,UMAGZ,3,2) = up(i,j,k,UMAGZ,3) - dt/(3.d0*dz)*(Ex(i,j+1,k+1) - Ex(i,j,k+1))
                                        
                                uR(i,j,k,UMAGX,3,2) = up(i,j,k,UMAGX,3) - dt/(6.d0*dz)*&
                                                                        ((Ez(i+1,j+1,k) - Ez(i+1,j,k)) + &
                                                                         (Ez(i  ,j+1,k) - Ez(i  ,j,k)))

                                uR(i,j,k,UMAGX,3,1) = up(i,j,k,UMAGX,3)
                                uR(i,j,k,UMAGY,3,2) = up(i,j,k,UMAGY,3)

                                uR(i,j,k,UEINT,1,1) = uR(i,j,k,UEINT,1,1) - 0.5d0*dot_product(uR(i,j,k,UMAGX:UMAGZ,1,1),uR(i,j,k,UMAGX:UMAGZ,1,1))

                                uR(i,j,k,UEINT,1,2) = uR(i,j,k,UEINT,1,2) -0.5d0*dot_product(uR(i,j,k,UMAGX:UMAGZ,1,2),uR(i,j,k,UMAGX:UMAGZ,1,2))

                                uR(i,j,k,UEINT,2,1) = uR(i,j,k,UEINT,2,1) -0.5d0*dot_product(uR(i,j,k,UMAGX:UMAGZ,2,1),uR(i,j,k,UMAGX:UMAGZ,2,1))

                                uR(i,j,k,UEINT,2,2) = uR(i,j,k,UEINT,2,2) -0.5d0*dot_product(uR(i,j,k,UMAGX:UMAGZ,2,2),uR(i,j,k,UMAGX:UMAGZ,2,2))

                                uR(i,j,k,UEINT,3,1) = uR(i,j,k,UEINT,3,1) -0.5d0*dot_product(uR(i,j,k,UMAGX:UMAGZ,3,1),uR(i,j,k,UMAGX:UMAGZ,3,1))

                                uR(i,j,k,UEINT,3,2) = uR(i,j,k,UEINT,3,2) -0.5d0*dot_product(uR(i,j,k,UMAGX:UMAGZ,3,2),uR(i,j,k,UMAGX:UMAGZ,3,2))
                        enddo
                enddo
        enddo

end subroutine corner_couple_mag

!====================================================== Final Conservative Corrections================================================================
subroutine half_step(lo, hi, &
                         uL, uR, um, up, q_l1,q_l2,q_l3,q_h1,q_h2,q_h3,&
                     flxx, flxx_l1,flxx_l2,flxx_l3,flxx_h1,flxx_h2,flxx_h3, &
                     flxy, flxy_l1,flxy_l2,flxy_l3,flxy_h1,flxy_h2,flxy_h3, &
                     flxz, flxz_l1,flxz_l2,flxz_l3,flxz_h1,flxz_h2,flxz_h3, &
                     dx, dy, dz, dt)
use amrex_fort_module, only : rt => amrex_real
use meth_params_module, only : NVAR, URHO, UEDEN, UMX, UMY, UMZ, URHO, UEINT, UFS
use network, only: nspec

implicit none
        
        integer, intent(in)       :: lo(3), hi(3),q_l1,q_l2,q_l3,q_h1,q_h2, q_h3
        integer, intent(in)   :: flxx_l1,flxx_l2,flxx_l3,flxx_h1,flxx_h2,flxx_h3
        integer, intent(in)   :: flxy_l1,flxy_l2,flxy_l3,flxy_h1,flxy_h2,flxy_h3
        integer, intent(in)   :: flxz_l1,flxz_l2,flxz_l3,flxz_h1,flxz_h2,flxz_h3
        
        real(rt), intent(in)    ::um(q_l1:q_h1,q_l2:q_h2,q_l3:q_h3,NVAR+3,3)
        real(rt), intent(in)    ::up(q_l1:q_h1,q_l2:q_h2,q_l3:q_h3,NVAR+3,3)

        real(rt), intent(out) :: flxx(flxx_l1:flxx_h1,flxx_l2:flxx_h2,flxx_l3:flxx_h3,NVAR+3,2)
        real(rt), intent(out) :: flxy(flxy_l1:flxy_h1,flxy_l2:flxy_h2,flxy_l3:flxy_h3,NVAR+3,2)
        real(rt), intent(out) :: flxz(flxz_l1:flxz_h1,flxz_l2:flxz_h2,flxz_l3:flxz_h3,NVAR+3,2)

        real(rt), intent(out)   ::uL(q_l1:q_h1,q_l2:q_h2,q_l3:q_h3,NVAR+3,3)
        real(rt), intent(out)   ::uR(q_l1:q_h1,q_l2:q_h2,q_l3:q_h3,NVAR+3,3)

        real(rt)                                :: dx, dy, dz, dt, u, v, w
        integer                                 :: i ,j ,k, n

        uL = um
        uR = up
        do k = lo(3), hi(3)
           do j = lo(2), hi(2)
              do i = lo(1), hi(1)
!left state                             
                 uL(i,j,k,URHO,1) = um(i,j,k,URHO,1) - 0.5d0*dt/dx*(flxy(i,j+1,k,URHO,2) - flxy(i,j,k,URHO,2)) &
                                          - 0.5d0*dt/dx*(flxz(i,j,k+1,URHO,2) - flxz(i,j,k,URHO,2))
                 uL(i,j,k,UMX,1) = um(i,j,k,UMX,1) - 0.5d0*dt/dx*(flxy(i,j+1,k,UMX,2) - flxy(i,j,k,UMX,2)) &
                                          - 0.5d0*dt/dx*(flxz(i,j,k+1,UMX,2) - flxz(i,j,k,UMX,2))
                 uL(i,j,k,UMY,1) = um(i,j,k,UMY,1) - 0.5d0*dt/dx*(flxy(i,j+1,k,UMY,2) - flxy(i,j,k,UMY,2)) &
                                         - 0.5d0*dt/dx*(flxz(i,j,k+1,UMY,2) - flxz(i,j,k,UMY,2))
                 uL(i,j,k,UMZ,1) = um(i,j,k,UMZ,1) - 0.5d0*dt/dx*(flxy(i,j+1,k,UMZ,2) - flxy(i,j,k,UMZ,2)) &
                                         - 0.5d0*dt/dx*(flxz(i,j,k+1,UMZ,2) - flxz(i,j,k,UMZ,2))
                 uL(i,j,k,UEDEN,1) = um(i,j,k,UEDEN,1) - 0.5d0*dt/dx*(flxy(i,j+1,k,UEDEN,2) - flxy(i,j,k,UEDEN,2)) &
                                         - 0.5d0*dt/dx*(flxz(i,j,k+1,UEDEN,2) - flxz(i,j,k,UEDEN,2))
                 uL(i,j,k,UFS:UFS+nspec-1,1) = um(i,j,k,UFS:UFS+nspec-1,1) - 0.5d0*dt/dx*(flxy(i,j+1,k,UFS:UFS+nspec-1,2) &
                                               - flxy(i,j,k,UFS:UFS+nspec-1,2)) - 0.5d0*dt/dx*(flxz(i,j,k+1,UFS:UFS+nspec-1,2) & 
                                               - flxz(i,j,k,UFS:UFS+nspec-1,2))


                 uL(i,j,k,URHO,2) = um(i,j,k,URHO,2) - 0.5d0*dt/dy*(flxx(i+1,j,k,URHO,2) - flxx(i,j,k,URHO,2)) &
                                          - 0.5d0*dt/dy*(flxz(i,j,k+1,URHO,1) - flxz(i,j,k,URHO,1))
                 uL(i,j,k,UMX,2) = um(i,j,k,UMX,2) - 0.5d0*dt/dy*(flxx(i+1,j,k,UMX,2) - flxx(i,j,k,UMX,2)) &
                                          - 0.5d0*dt/dy*(flxz(i,j,k+1,UMX,1) - flxz(i,j,k,UMX,1))
                 uL(i,j,k,UMY,2) = um(i,j,k,UMY,2) - 0.5d0*dt/dy*(flxx(i+1,j,k,UMY,2) - flxx(i,j,k,UMY,2)) &
                                          - 0.5d0*dt/dy*(flxz(i,j,k+1,UMY,1) - flxz(i,j,k,UMY,1))
                 uL(i,j,k,UMZ,2) = um(i,j,k,UMZ,2) - 0.5d0*dt/dy*(flxx(i+1,j,k,UMZ,2) - flxx(i,j,k,UMZ,2)) &
                                          - 0.5d0*dt/dy*(flxz(i,j,k+1,UMZ,1) - flxz(i,j,k,UMZ,1))
                 uL(i,j,k,UEDEN,2) = um(i,j,k,UEDEN,2) - 0.5d0*dt/dy*(flxx(i+1,j,k,UEDEN,2) - flxx(i,j,k,UEDEN,2)) &
                                          - 0.5d0*dt/dy*(flxz(i,j,k+1,UEDEN,1) - flxz(i,j,k,UEDEN,1))
                 uL(i,j,k,UFS:UFS+nspec-1,2) = um(i,j,k,UFS:UFS+nspec-1,2) - 0.5d0*dt/dy*(flxx(i+1,j,k,UFS:UFS+nspec-1,2) & 
                                               - flxx(i,j,k,UFS:UFS+nspec-1,2)) - 0.5d0*dt/dy*(flxz(i,j,k+1,UFS:UFS+nspec-1,1) &
                                               - flxz(i,j,k,UFS:UFS+nspec-1,1))

                 uL(i,j,k,URHO,3) = um(i,j,k,URHO,3) - 0.5d0*dt/dz*(flxx(i+1,j,k,URHO,1) - flxx(i,j,k,URHO,1)) &
                                          - 0.5d0*dt/dz*(flxy(i,j+1,k,URHO,1) - flxy(i,j,k,URHO,1))
                 uL(i,j,k,UMX,3) = um(i,j,k,UMX,3) - 0.5d0*dt/dz*(flxx(i+1,j,k,UMX,1) - flxx(i,j,k,UMX,1)) &
                                          - 0.5d0*dt/dz*(flxy(i,j+1,k,UMX,1) - flxy(i,j,k,UMX,1))
                 uL(i,j,k,UMY,3) = um(i,j,k,UMY,3) - 0.5d0*dt/dz*(flxx(i+1,j,k,UMY,1) - flxx(i,j,k,UMY,1)) &
                                          - 0.5d0*dt/dz*(flxy(i,j+1,k,UMY,1) - flxy(i,j,k,UMY,1))
                 uL(i,j,k,UMZ,3) = um(i,j,k,UMZ,3) - 0.5d0*dt/dz*(flxx(i+1,j,k,UMZ,1) - flxx(i,j,k,UMZ,1)) &
                                          - 0.5d0*dt/dz*(flxy(i,j+1,k,UMZ,1) - flxy(i,j,k,UMZ,1))
                 uL(i,j,k,UEDEN,3) = um(i,j,k,UEDEN,3) - 0.5d0*dt/dz*(flxx(i+1,j,k,UEDEN,1) - flxx(i,j,k,UEDEN,1)) &
                                          - 0.5d0*dt/dz*(flxy(i,j+1,k,UEDEN,1) - flxy(i,j,k,UEDEN,1))
                 uL(i,j,k,UFS:UFS+nspec-1,3) = um(i,j,k,UFS:UFS+nspec-1,3) - 0.5d0*dt/dz*(flxx(i+1,j,k,UFS:UFS+nspec-1,1) & 
                                              - flxx(i,j,k,UFS:UFS+nspec-1,1)) - 0.5d0*dt/dz*(flxy(i,j+1,k,UFS:UFS+nspec-1,1) &
                                              - flxy(i,j,k,UFS:UFS+nspec-1,1))

                        
                                do n = 1,3
                                        u = uL(i,j,k,UMX,n)/uL(i,j,k,URHO,n)
                                        v = uL(i,j,k,UMY,n)/uL(i,j,k,URHO,n)
                                        w = uL(i,j,k,UMZ,n)/uL(i,j,k,URHO,n)
     
                                        uL(i,j,k,UEINT,n) = uL(i,j,k,UEDEN,n) - 0.5d0*uL(i,j,k,URHO,n)*(u**2 + v**2 + w**2)
                                enddo
!right state                            
                 uR(i,j,k,URHO,1) = up(i,j,k,URHO,1) - 0.5d0*dt/dx*(flxy(i,j+1,k,URHO,2) - flxy(i,j,k,URHO,2)) &
                                          - 0.5d0*dt/dx*(flxz(i,j,k+1,URHO,2) - flxz(i,j,k,URHO,2))
                 uR(i,j,k,UMX,1) = up(i,j,k,UMX,1) - 0.5d0*dt/dx*(flxy(i,j+1,k,UMX,2) - flxy(i,j,k,UMX,2)) &
                                          - 0.5d0*dt/dx*(flxz(i,j,k+1,UMX,2) - flxz(i,j,k,UMX,2))
                 uR(i,j,k,UMY,1) = up(i,j,k,UMY,1) - 0.5d0*dt/dx*(flxy(i,j+1,k,UMY,2) - flxy(i,j,k,UMY,2)) &
                                          - 0.5d0*dt/dx*(flxz(i,j,k+1,UMY,2) - flxz(i,j,k,UMY,2))
                 uR(i,j,k,UMZ,1) = up(i,j,k,UMZ,1) - 0.5d0*dt/dx*(flxy(i,j+1,k,UMZ,2) - flxy(i,j,k,UMZ,2)) &
                                          - 0.5d0*dt/dx*(flxz(i,j,k+1,UMZ,2) - flxz(i,j,k,UMZ,2))
                 uR(i,j,k,UEDEN,1) = up(i,j,k,UEDEN,1) - 0.5d0*dt/dx*(flxy(i,j+1,k,UEDEN,2) - flxy(i,j,k,UEDEN,2)) &
                                          - 0.5d0*dt/dx*(flxz(i,j,k+1,UEDEN,2) - flxz(i,j,k,UEDEN,2))
                 uR(i,j,k,UFS:UFS+nspec-1,1) = up(i,j,k,UFS:UFS+nspec-1,1) - 0.5d0*dt/dx*(flxy(i,j+1,k,UFS:UFS+nspec-1,2) & 
                                             - flxy(i,j,k,UFS:UFS+nspec-1,2)) - 0.5d0*dt/dx*(flxz(i,j,k+1,UFS:UFS+nspec-1,2) &
                                             - flxz(i,j,k,UFS:UFS+nspec-1,2))

                 uR(i,j,k,URHO,2) = up(i,j,k,URHO,2) - 0.5d0*dt/dy*(flxx(i+1,j,k,URHO,2) - flxx(i,j,k,URHO,2)) &
                                          - 0.5d0*dt/dy*(flxz(i,j,k+1,URHO,1) - flxz(i,j,k,URHO,1))
                 uR(i,j,k,UMX,2) = up(i,j,k,UMX,2) - 0.5d0*dt/dy*(flxx(i+1,j,k,UMX,2) - flxx(i,j,k,UMX,2)) &
                                          - 0.5d0*dt/dy*(flxz(i,j,k+1,UMX,1) - flxz(i,j,k,UMX,1))
                 uR(i,j,k,UMY,2) = up(i,j,k,UMY,2) - 0.5d0*dt/dy*(flxx(i+1,j,k,UMY,2) - flxx(i,j,k,UMY,2)) &
                                          - 0.5d0*dt/dy*(flxz(i,j,k+1,UMY,1) - flxz(i,j,k,UMY,1))
                 uR(i,j,k,UMZ,2) = up(i,j,k,UMZ,2) - 0.5d0*dt/dy*(flxx(i+1,j,k,UMZ,2) - flxx(i,j,k,UMZ,2)) &
                                          - 0.5d0*dt/dy*(flxz(i,j,k+1,UMZ,1) - flxz(i,j,k,UMZ,1))
                 uR(i,j,k,UEDEN,2) = up(i,j,k,UEDEN,2) - 0.5d0*dt/dy*(flxx(i+1,j,k,UEDEN,2) - flxx(i,j,k,UEDEN,2)) &
                                          - 0.5d0*dt/dy*(flxz(i,j,k+1,UEDEN,1) - flxz(i,j,k,UEDEN,1))
                 uR(i,j,k,UFS:UFS+nspec-1,2) = up(i,j,k,UFS:UFS+nspec-1,2) - 0.5d0*dt/dy*(flxx(i+1,j,k,UFS:UFS+nspec-1,2) & 
                                             - flxx(i,j,k,UFS:UFS+nspec-1,2)) - 0.5d0*dt/dy*(flxz(i,j,k+1,UFS:UFS+nspec-1,1) & 
                                             - flxz(i,j,k,UFS:UFS+nspec-1,1))

                 uR(i,j,k,URHO,3) = up(i,j,k,URHO,3) - 0.5d0*dt/dz*(flxx(i+1,j,k,URHO,1) - flxx(i,j,k,URHO,1)) &
                                          - 0.5d0*dt/dz*(flxy(i,j+1,k,URHO,1) - flxy(i,j,k,URHO,1))
                 uR(i,j,k,UMX,3) = up(i,j,k,UMX,3) - 0.5d0*dt/dz*(flxx(i+1,j,k,UMX,1) - flxx(i,j,k,UMX,1)) &
                                          - 0.5d0*dt/dz*(flxy(i,j+1,k,UMX,1) - flxy(i,j,k,UMX,1))
                 uR(i,j,k,UMY,3) = up(i,j,k,UMY,3) - 0.5d0*dt/dz*(flxx(i+1,j,k,UMY,1) - flxx(i,j,k,UMY,1)) &
                                          - 0.5d0*dt/dz*(flxy(i,j+1,k,UMY,1) - flxy(i,j,k,UMY,1))
                 uR(i,j,k,UMZ,3) = up(i,j,k,UMZ,3) - 0.5d0*dt/dz*(flxx(i+1,j,k,UMZ,1) - flxx(i,j,k,UMZ,1)) &
                                          - 0.5d0*dt/dz*(flxy(i,j+1,k,UMZ,1) - flxy(i,j,k,UMZ,1))
                 uR(i,j,k,UEDEN,3) = up(i,j,k,UEDEN,3) - 0.5d0*dt/dz*(flxx(i+1,j,k,UEDEN,1) - flxx(i,j,k,UEDEN,1)) &
                                          - 0.5d0*dt/dz*(flxy(i,j+1,k,UEDEN,1) - flxy(i,j,k,UEDEN,1))
                 uR(i,j,k,UFS:UFS+nspec-1,3) = up(i,j,k,UFS:UFS+nspec-1,3) - 0.5d0*dt/dz*(flxx(i+1,j,k,UFS:UFS+nspec-1,1) &
                                             - flxx(i,j,k,UFS:UFS+nspec-1,1)) - 0.5d0*dt/dz*(flxy(i,j+1,k,UFS:UFS+nspec-1,1) & 
                                             - flxy(i,j,k,UFS:UFS+nspec-1,1))



                                do n = 1,3
                                        u = uR(i,j,k,UMX,n)/uR(i,j,k,URHO,n)
                                        v = uR(i,j,k,UMY,n)/uR(i,j,k,URHO,n)
                                        w = uR(i,j,k,UMZ,n)/uR(i,j,k,URHO,n)
                                        uR(i,j,k,UEINT,n) = uR(i,j,k,UEDEN,n) - 0.5d0*uR(i,j,k,URHO,n)*(u**2 + v**2 + w**2)
                                enddo
                        enddo
                enddo
        enddo
end subroutine 

!================================================= Final Magnetic Corrections ========================================================================
subroutine half_step_mag(lo, hi, &
                                 uL, uR, um, up, q_l1, q_l2, q_l3, q_h1, q_h2, q_h3, &
                         Ex, ex_l1,ex_l2,ex_l3,ex_h1,ex_h2,ex_h3, &
                                 Ey, ey_l1,ey_l2,ey_l3,ey_h1,ey_h2,ey_h3, &
                                 Ez, ez_l1,ez_l2,ez_l3,ez_h1,ez_h2,ez_h3, &
                                 dx, dy, dz, dt)
use amrex_fort_module, only : rt => amrex_real
use meth_params_module, only : NVAR, UEINT

!Correction using Faraday's Law
implicit none

        integer, intent(in)   :: lo(3), hi(3), q_l1,q_l2,q_l3,q_h1,q_h2, q_h3
        integer, intent(in)   :: ex_l1,ex_l2,ex_l3,ex_h1,ex_h2,ex_h3
        integer, intent(in)   :: ey_l1,ey_l2,ey_l3,ey_h1,ey_h2,ey_h3
        integer, intent(in)   :: ez_l1,ez_l2,ez_l3,ez_h1,ez_h2,ez_h3

        real(rt), intent(inout)         ::uL(q_l1:q_h1,q_l2:q_h2,q_l3:q_h3,NVAR+3,3)
        real(rt), intent(inout)     ::uR(q_l1:q_h1,q_l2:q_h2,q_l3:q_h3,NVAR+3,3)
        real(rt), intent(in)            ::um(q_l1:q_h1,q_l2:q_h2,q_l3:q_h3,NVAR+3,3)
        real(rt), intent(in)            ::up(q_l1:q_h1,q_l2:q_h2,q_l3:q_h3,NVAR+3,3)    

        real(rt), intent(in)  :: Ex(ex_l1:ex_h1,ex_l2:ex_h2,ex_l3:ex_h3)
        real(rt), intent(in)  :: Ey(ey_l1:ey_h1,ey_l2:ey_h2,ey_l3:ey_h3)
        real(rt), intent(in)  :: Ez(ez_l1:ez_h1,ez_l2:ez_h2,ez_l3:ez_h3)

        real(rt)                                        :: dx, dy, dz, dt
        integer                                         :: i ,j ,k, n
        integer      :: UMAGX, UMAGY, UMAGZ

        UMAGX = NVAR+1
        UMAGY = NVAR+2
        UMAGZ = NVAR+3

        do k = lo(3), hi(3)
                do j = lo(2), hi(2)
                        do i = lo(1), hi(1)
                !---------------------------------------left state-----------------------------------------------------
                                !X-Direction
                                !Bx
                                uL(i,j,k,UMAGX,1) = um(i,j,k,UMAGX,1) - 0.5d0*dt/dx*((Ey(i,j,k+1) - Ey(i,j,k)) &
                                                                                   - (Ez(i,j+1,k) - Ez(i,j,k)))
                                !By
                                uL(i,j,k,UMAGY,1) = um(i,j,k,UMAGY,1) - 0.5d0*dt/dx*((Ex(i  ,j+1,k+1) - Ex(i,j+1,k)) &
                                                                                   + (Ex(i  ,j  ,k+1) - Ex(i,j  ,k)) &
                                                                                   - (Ez(i+1,j+1,k  ) - Ez(i,j+1,k)) &
                                                                                   - (Ez(i+1,j  ,k  ) - Ez(i,j  ,k)))
                                !Bz
                                uL(i,j,k,UMAGZ,1) = um(i,j,k,UMAGZ,1) + 0.5d0*dt/dx*((Ex(i  ,j+1,k+1) - Ex(i,j,k+1)) &
                                                                                   + (Ex(i  ,j+1,k  ) - Ex(i,j,k  )) &
                                                                                   - (Ey(i+1,j  ,k+1) - Ey(i,j,k+1)) &
                                                                                   - (Ey(i+1,j  ,k  ) - Ey(i,j,k  )))
                                !Y-Direction
                                !Bx
                                uL(i,j,k,UMAGX,2) = um(i,j,k,UMAGX,2) + 0.5d0*dt/dy*((Ey(i+1,j,k+1) - Ey(i+1,j,k)) &
                                                                                   + (Ey(i  ,j,k+1) - Ey(i  ,j,k)) &
                                                                                   - (Ez(i+1,j+1,k) - Ez(i+1,j,k)) &
                                                                                   - (Ez(i  ,j+1,k) - Ez(i  ,j,k)))
                                !By
                                uL(i,j,k,UMAGY,2) = um(i,j,k,UMAGY,2) + 0.5d0*dt/dy*((Ex(i,j,k+1) - Ex(i,j,k)) &
                                                                                   - (Ez(i+1,j,k) - Ez(i,j,k)))
                                !Bz
                                uL(i,j,k,UMAGZ,2) = um(i,j,k,UMAGZ,2) - 0.5d0*dt/dy*((Ey(i+1,j,k+1) - Ey(i,j,k+1)) &
                                                                                   + (Ey(i+1,j,k  ) - Ey(i,j,k  )) &
                                                                                   - (Ex(i,j+1,k+1) - Ex(i,j,k+1)) &
                                                                                   - (Ex(i,j+1,k  ) - Ex(i,j,k  )))
                                !Z-direction
                                !Bx
                                uL(i,j,k,UMAGX,3) = um(i,j,k,UMAGX,3) - 0.5d0*dt/dz*((Ez(i+1,j+1,k) - Ez(i+1,j,k)) &
                                                                                   + (Ez(i  ,j+1,k) - Ez(i  ,j,k)) &
                                                                                   - (Ey(i+1,j,k+1) - Ey(i+1,j,k)) &
                                                                                   - (Ey(i  ,j,k+1) - Ey(i  ,j,k)))
                                !By
                                uL(i,j,k,UMAGY,3) = um(i,j,k,UMAGY,3) + 0.5d0*dt/dz*((Ez(i+1,j+1,k  ) - Ez(i,j+1,k)) &
                                                                                    +(Ez(i+1,j  ,k  ) - Ez(i,j  ,k)) &
                                                                                    -(Ex(i  ,j+1,k+1) - Ex(i,j+1,k)) &
                                                                                   - (Ex(i  ,j  ,k+1) - Ex(i,j  ,k)))
                                !Bz
                                uL(i,j,k,UMAGZ,3) = um(i,j,k,UMAGZ,3) - 0.5d0*dt/dz*((Ex(i,j+1,k) - Ex(i,j,k)) &
                                                                                   - (Ey(i+1,j,k) - Ey(i,j,k)))
                                do n = 1,3
                                        uL(i,j,k,UEINT,n) = uL(i,j,k,UEINT,n) - 0.5d0*dot_product(uL(i,j,k,UMAGX:UMAGZ,n),uL(i,j,k,UMAGX:UMAGZ,n))
                                enddo

        !---------------------------------------right state-----------------------------------------------------
                                !X-Direction
                                !Bx
                                uR(i,j,k,UMAGX,1) = up(i,j,k,UMAGX,1) - 0.5d0*dt/dx*((Ey(i+1,j,k+1) - Ey(i+1,j,k)) &
                                                                    -                (Ez(i+1,j+1,k) - Ez(i+1,j,k)))
                                !By
                                uR(i,j,k,UMAGY,1) = up(i,j,k,UMAGY,1) - 0.5d0*dt/dx*((Ex(i  ,j+1,k+1) - Ex(i,j+1,k)) &
                                                                                   + (Ex(i  ,j  ,k+1) - Ex(i,j  ,k)) &
                                                                                   - (Ez(i+1,j+1,k  ) - Ez(i,j+1,k)) &
                                                                                   - (Ez(i+1,j  ,k  ) - Ez(i,j  ,k)))
                                !Bz
                                uR(i,j,k,UMAGZ,1) = up(i,j,k,UMAGZ,1) + 0.5d0*dt/dx*((Ex(i,j+1,k+1) - Ex(i,j,k+1)) &
                                                                                   + (Ex(i,j+1,k  ) - Ex(i,j,k  )) &
                                                                                   - (Ey(i+1,j,k+1) - Ey(i,j,k+1)) &
                                                                                   - (Ey(i+1,j,k  ) - Ey(i,j,k  )))                             
                                !Y-Direction
                                !Bx
                                uR(i,j,k,UMAGX,2) = up(i,j,k,UMAGX,2) + 0.5d0*dt/dy*((Ey(i+1,j,k+1) - Ey(i+1,j,k)) &
                                                                                   + (Ey(i  ,j,k+1) - Ey(i  ,j,k)) &
                                                                                   - (Ez(i+1,j+1,k) - Ez(i+1,j,k)) &
                                                                                   - (Ez(i  ,j+1,k) - Ez(i,j,k)))
                                !By
                                uR(i,j,k,UMAGY,2) = up(i,j,k,UMAGY,2) + 0.5d0*dt/dy*((Ex(i,j+1,k+1) - Ex(i,j+1,k)) &
                                                                    - (Ez(i+1,j+1,k) - Ez(i,j+1,k)))
                                !Bz
                                uR(i,j,k,UMAGZ,2) = up(i,j,k,UMAGZ,2) - 0.5d0*dt/dy*((Ey(i+1,j,k+1) - Ey(i,j,k+1)) &
                                                                        + (Ey(i+1,j,k) - Ey(i,j,k)) &
                                                                        - (Ex(i,j+1,k+1) - Ex(i,j,k+1)) &
                                                                        - (Ex(i,j+1,k) - Ex(i,j,k)))    
                
                                !Z-direction
                                !Bx
                                uR(i,j,k,UMAGX,3) = up(i,j,k,UMAGX,3) - 0.5d0*dt/dz*((Ez(i+1,j+1,k) - Ez(i+1,j,k)) &
                                                                        + (Ez(i,j+1,k) - Ez(i,j,k)) &
                                                                        - (Ey(i+1,j,k+1) - Ey(i+1,j,k)) &
                                                                        - (Ey(i,j,k+1) - Ey(i,j,k)))
                                !By
                                uR(i,j,k,UMAGY,3) = up(i,j,k,UMAGY,3) + 0.5d0*dt/dz*((Ez(i+1,j+1,k  ) - Ez(i,j+1,k)) &
                                                                                   + (Ez(i+1,j  ,k  ) - Ez(i,j  ,k)) &
                                                                                   - (Ex(i  ,j+1,k+1) - Ex(i,j+1,k)) &
                                                                                   - (Ex(i  ,j  ,k+1) - Ex(i,j,k)))
                                !Bz
                                uR(i,j,k,UMAGZ,3) = up(i,j,k,UMAGZ,3) - 0.5d0*dt/dz*((Ex(i,j+1,k+1) - Ex(i,j,k+1)) &
                                                                                   - (Ey(i+1,j,k+1) - Ey(i,j,k+1)))                     
                                do n = 1,3
                                        uR(i,j,k,UEINT,n) = uR(i,j,k,UEINT,n) -0.5d0*dot_product(uR(i,j,k,UMAGX:UMAGZ,n),uR(i,j,k,UMAGX:UMAGZ,n))
                                enddo   
                        enddo
                enddo
        enddo

end subroutine half_step_mag

!================================== Find the 2D corrected primitive variables =======================================
subroutine prim_half(q2D,q,q_l1,q_l2,q_l3,q_h1,q_h2,q_h3, &
                     flxx, flxx_l1,flxx_l2,flxx_l3,flxx_h1,flxx_h2,flxx_h3, &
                     flxy, flxy_l1,flxy_l2,flxy_l3,flxy_h1,flxy_h2,flxy_h3, &
                     flxz, flxz_l1,flxz_l2,flxz_l3,flxz_h1,flxz_h2,flxz_h3, &
                     dx, dy, dz, dt)

 use amrex_fort_module, only : rt => amrex_real
 use meth_params_module, only : NVAR

implicit none

        integer, intent(in)             ::q_l1,q_l2,q_l3,q_h1,q_h2, q_h3

        integer, intent(in)   :: flxx_l1,flxx_l2,flxx_l3,flxx_h1,flxx_h2,flxx_h3
        integer, intent(in)   :: flxy_l1,flxy_l2,flxy_l3,flxy_h1,flxy_h2,flxy_h3
        integer, intent(in)   :: flxz_l1,flxz_l2,flxz_l3,flxz_h1,flxz_h2,flxz_h3

        real(rt), intent(in)    :: q(q_l1:q_h1,q_l2:q_h2,q_l3:q_h3,NQ)
        real(rt), intent(in)    :: flxx(flxx_l1:flxx_h1,flxx_l2:flxx_h2,flxx_l3:flxx_h3,NVAR+3)
        real(rt), intent(in)    :: flxy(flxy_l1:flxy_h1,flxy_l2:flxy_h2,flxy_l3:flxy_h3,NVAR+3)
        real(rt), intent(in)    :: flxz(flxz_l1:flxz_h1,flxz_l2:flxz_h2,flxz_l3:flxz_h3,NVAR+3)

        real(rt), intent(out)   ::q2D(q_l1:q_h1,q_l2:q_h2,q_l3:q_h3,NQ)

        real(rt)                                ::flx_sum(NVAR+3)
        real(rt)                                ::qflx(NQ)
        real(rt)                                :: dx, dy, dz, dt       
        integer                                 ::i, j, k

        do k = q_l3+1,q_h3-1
                do j = q_l2+1,q_h2-1
                        do i = q_l1+1,q_h1-1
                                flx_sum = (flxx(i+1,j,k,:) - flxx(i,j,k,:)) + (flxy(i,j+1,k,:) - flxy(i,j,k,:)) + (flxz(i,j,k+1,:) - flxz(i,j,k,:)) 
                                call qflux(qflx,flx_sum,q(i,j,k,:))
                                !Right below eq. 48 
                                q2D(i,j,k,:) = q(i,j,k,:) - 0.5d0*dt/dx*qflx
                        enddo
                enddo
        enddo
end subroutine prim_half


!================================= Calculate the C to P Jacobian applied to the fluxes ===================================

subroutine qflux(qflx,flx,q)
 use amrex_fort_module, only : rt => amrex_real
 use meth_params_module !,only : QRHO, QU, QV, QW, QPRES, QMAGX, QMAGY, QMAGZ, QVAR, NVAR
 use eos_module, only : eos
 use eos_type_module, only: eos_t, eos_input_rp
 use network, only : nspec
 
 implicit none

 ! this is step 10 in the paper, just after Eq. 48

 ! this seems to implement dW/dU . qflux, where dW/dU is the Jacobian of
 ! the primitive quantities (W) with respect to conserved quantities (U) 

 real(rt), intent(in)           ::flx(NVAR+3), q(NQ)
 real(rt), intent(out)          ::qflx(NQ)
 real(rt) :: dedp, dedrho, totalE

 integer :: UMAGX, UMAGY, UMAGZ
  
 type (eos_t) :: eos_state
  
        UMAGX = NVAR+1
        UMAGY = NVAR+2
        UMAGZ = NVAR+3

        qflx = 0.d0
        qflx(QRHO)  = flx(URHO)
        qflx(QU)    = ( flx(UMX) - flx(URHO) * q(QU) )/q(QRHO)
        qflx(QV)    = ( flx(UMY) - flx(URHO) * q(QV) )/q(QRHO)
        qflx(QW)    = ( flx(UMZ) - flx(URHO) * q(QW) )/q(QRHO)
       
        qflx(QFS:QFS+nspec-1)  = ( flx(UFS:UFS+nspec-1) - flx(URHO) * q(QFS:QFS+nspec-1) )/q(QRHO)
            
        eos_state % rho = q(QRHO)
        eos_state % p   = q(QPRES)
        eos_state % T   = 100.d0 !dummy initial guess 
        eos_state % xn  = q(QFS:QFS+nspec-1)

        call eos(eos_input_rp, eos_state)

        dedrho  = eos_state % dedr - eos_state % dedT * eos_state % dPdr * 1.0d0/eos_state % dPdT
        dedp    = eos_state % dedT * 1.0d0/eos_state % dPdT

        qflx(QPRES) = ( -q(QMAGX)*flx(UMAGX) - q(QMAGY)*flx(UMAGY) - q(QMAGZ)*flx(UMAGZ) + &
                         flx(UEDEN) - flx(UMX)*q(QU) - flx(UMY)*q(QV) - &
                         flx(UMZ)*q(QW) + flx(URHO)*(0.5*(q(QU)**2+q(QV)**2+q(QW)**2) - &
                         eos_state % e -q(QRHO)*dedrho) ) / ( dedp * q(QRHO))
        qflx(QMAGX) = flx(UMAGX)
        qflx(QMAGY) = flx(UMAGY)
        qflx(QMAGZ) = flx(UMAGZ)

end subroutine qflux


!============================================ Debug code =====================================================
        subroutine checkisnanmult(uout,uout_l1,uout_l2,uout_l3,uout_h1,uout_h2,uout_h3, num)
           use amrex_fort_module, only : rt => amrex_real

        implicit none
        integer, intent(in)  :: uout_l1,uout_l2,uout_l3,uout_h1,uout_h2,uout_h3, num
        real(rt), intent(in) :: uout(uout_l1:uout_h1,uout_l2:uout_h2,uout_l3:uout_h3,num)

        integer :: i,j,k,n


        do n = 1,num
                do k = uout_l3,uout_h3
                        do j = uout_l2, uout_h2
                                do i = uout_l1,uout_h1
                                        if(isnan(uout(i,j,k,n)).or.(abs(uout(i,j,k,n)).ge. 1d14)) then
                                                write(*,*) "Bad values ",  uout(i,j,k,:)
                                                write(*,*) "Failure to converge ", "i, j, k, n = ", i, j, k, n
                                                stop
                                        endif
                                enddo
                        enddo
                enddo
        enddo
        end subroutine checkisnanmult
!============ single =====================      

        subroutine checkisnans(uout,uout_l1,uout_l2,uout_l3,uout_h1,uout_h2,uout_h3)
           use amrex_fort_module, only : rt => amrex_real

        implicit none
        integer, intent(in)  :: uout_l1,uout_l2,uout_l3,uout_h1,uout_h2,uout_h3
        real(rt), intent(in) :: uout(uout_l1:uout_h1,uout_l2:uout_h2,uout_l3:uout_h3)

        integer :: i,j,k

                do k = uout_l3,uout_h3
                        do j = uout_l2, uout_h2
                                do i = uout_l1,uout_h1
                                        if(isnan(uout(i,j,k)).or.(abs(uout(i,j,k)).ge. 1d14)) then
                                                write(*,*) "Bad values ",  uout(i,j,k)
                                                write(*,*) "Failure to converge ", "i, j, k = ", i, j, k
                                                stop
                                        endif
                                enddo
                        enddo
                enddo
        end subroutine checkisnans

!====================================== Density Check ========================================
        subroutine checknegdens(uout,uout_l1,uout_l2,uout_l3,uout_h1,uout_h2,uout_h3)
           use amrex_fort_module, only : rt => amrex_real

        implicit none
        integer, intent(in)  :: uout_l1,uout_l2,uout_l3,uout_h1,uout_h2,uout_h3
        real(rt), intent(in) :: uout(uout_l1:uout_h1,uout_l2:uout_h2,uout_l3:uout_h3)

        integer :: i,j,k

                do k = uout_l3,uout_h3
                        do j = uout_l2, uout_h2
                                do i = uout_l1,uout_h1
                                        if(uout(i,j,k).le. 0.d0) then
                                                write(*,*) "Non-Positive Density ",  uout(i,j,k)
                                                write(*,*) "i, j, k = ", i, j, k
                                                stop
                                        endif
                                enddo
                        enddo
                enddo
        end subroutine checknegdens
end module ct_upwind