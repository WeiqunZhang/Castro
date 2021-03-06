///
/// Construct gravitational field at old timestep
///
/// @param amr_iteration    where we are in the current AMR subcycle
/// @param amr_ncycle       the number of subcycles at this level
/// @param time             current time
///
    void construct_old_gravity(int amr_iteration, int amr_ncycle,
                               amrex::Real time);


///
/// Construct gravitational field at new timestep
///
/// @param amr_iteration    where we are in the current AMR subcycle
/// @param amr_ncycle       the number of subcycles at this level
/// @param time             current time
///
    void construct_new_gravity(int amr_iteration, int amr_ncycle,
                               amrex::Real time);

///
/// Construct gravitational source terms at old timestep
///
/// @param source   MultiFab to save sources to
/// @param state    Old state
/// @param time     current time
/// @param dt       timestep
///
    void construct_old_gravity_source(amrex::MultiFab& source, amrex::MultiFab& state, amrex::Real time, amrex::Real dt);


///
/// Construct gravitational source terms at new timestep
///
/// @param source       MultiFab to save sources to
/// @param state_old    Old state
/// @param state_new    New state
/// @param time         current time
/// @param dt           timestep
///
    void construct_new_gravity_source(amrex::MultiFab& source, amrex::MultiFab& state_old, amrex::MultiFab& state_new, amrex::Real time, amrex::Real dt);

